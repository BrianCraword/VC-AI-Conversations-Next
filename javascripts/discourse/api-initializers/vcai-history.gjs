import { apiInitializer } from "discourse/lib/api";
import { ajax } from "discourse/lib/ajax";
import DiscourseURL from "discourse/lib/url";
import { i18n } from "discourse-i18n";
import {
  ensureRouteState,
  nextPaint,
  onRouteState,
  routeState,
} from "../lib/vcai-route-state";

/* VC AI Conversations Next — History module
 * Lineage: VC AI History Next 1.3.0 ("Console" feed). Behaviour carried over
 * intact; see CHANGELOG for what changed in the consolidation.
 */

const PANEL_SELECTOR = ".sidebar-sections.ai-conversations-panel";
const ROW_SELECTOR = ".sidebar-section-link.sidebar-row";
const HEADER_SELECTOR = ".sidebar-section-header";
const ROOT_CLASS = "vcai-history";
const PERSISTENT_CLASS = "vcai-history--persistent";
const OPEN_CLASS = "vcai-history--drawer-open";
const NATIVE_MOBILE_CLASS = "vcai-history--native-mobile";
const CHROME_HIDDEN_CLASS = "vcai-history--chrome-hidden";
const CHROME_CLASS = "vcai-history-chrome";
const TOGGLE_ID = "vcai-history-toggle";
const BACKDROP_ID = "vcai-history-backdrop";
const SEARCH_ID = "vcai-history-search";
const FILTER_ID = "vcai-history-filter";
const SCOPES_ID = "vcai-history-scopes";
const SHELF_ID = "vcai-history-shelf";
const HINT_ID = "vcai-history-hint";
const MENU_ID = "vcai-history-menu";
const SCRIM_ID = "vcai-history-menu-scrim";
const TOAST_ID = "vcai-history-toast";
const HIDDEN_CLASS = "vcai-history-hidden";
const ACTIVE_CLASS = "vcai-history-row--active";
const KEYED_CLASS = "vcai-history-row--keyed";
const EVERYONE = ["everyone", "all", "trust_level_0"];

const NATIVE_TOGGLE_CHAIN = [
  ".btn-sidebar-toggle",
  "#toggle-hamburger-menu",
  ".hamburger-dropdown button",
];

const ICONS = {
  search:
    '<circle cx="9" cy="9" r="5.6"/><path d="M13.2 13.2L17 17" stroke-linecap="round"/>',
  dots:
    '<circle cx="10" cy="5" r="1.6" fill="currentColor" stroke="none"/><circle cx="10" cy="10" r="1.6" fill="currentColor" stroke="none"/><circle cx="10" cy="15" r="1.6" fill="currentColor" stroke="none"/>',
  pencil:
    '<path d="M4 16h3l9-9-3-3-9 9v3z" stroke-linecap="round" stroke-linejoin="round"/><path d="M12.6 4.4l3 3" stroke-linecap="round"/>',
  trash:
    '<path d="M4 6h12M7.4 6V4.4h5.2V6" stroke-linecap="round"/><path d="M5.7 6l.75 9.1a1 1 0 0 0 1 .9h5.1a1 1 0 0 0 1-.9L14.3 6" stroke-linecap="round" stroke-linejoin="round"/>',
  star:
    '<path d="M10 2.9l2 4.4 4.8.5-3.6 3.2 1 4.8L10 13.4 5.8 15.8l1-4.8L3.2 7.8l4.8-.5z" stroke-linejoin="round"/>',
  starFilled:
    '<path d="M10 2.9l2 4.4 4.8.5-3.6 3.2 1 4.8L10 13.4 5.8 15.8l1-4.8L3.2 7.8l4.8-.5z" fill="currentColor" stroke="none"/>',
  check: '<path d="M4.5 10.5l3.5 3.5 7.5-8" stroke-linecap="round" stroke-linejoin="round"/>',
  close: '<path d="M5.5 5.5l9 9M14.5 5.5l-9 9" stroke-linecap="round"/>',
};

function icon(name, strokeWidth = 1.7) {
  const node = document.createElementNS("http://www.w3.org/2000/svg", "svg");
  node.setAttribute("viewBox", "0 0 20 20");
  node.setAttribute("fill", "none");
  node.setAttribute("stroke", "currentColor");
  node.setAttribute("stroke-width", String(strokeWidth));
  node.setAttribute("aria-hidden", "true");
  node.setAttribute("focusable", "false");
  node.innerHTML = ICONS[name] || "";
  return node;
}

function parseGroups(raw) {
  return String(raw || "")
    .split(/[|,]/)
    .map((name) => name.trim())
    .filter(Boolean);
}

function shortAge(value) {
  const then = value ? Date.parse(value) : NaN;
  if (Number.isNaN(then)) {
    return null;
  }
  const seconds = Math.max(0, (Date.now() - then) / 1000);
  if (seconds < 3600) {
    return Math.max(1, Math.round(seconds / 60)) + "M";
  }
  if (seconds < 86400) {
    return Math.round(seconds / 3600) + "H";
  }
  if (seconds < 2592000) {
    return Math.round(seconds / 86400) + "D";
  }
  if (seconds < 31536000) {
    return Math.round(seconds / 2592000) + "MO";
  }
  return Math.round(seconds / 31536000) + "Y";
}

export default apiInitializer((api) => {
  if (settings.vcai_enabled !== true || settings.vcai_history_enabled !== true) {
    return;
  }

  const t = (key, options) => i18n(themePrefix("vcai_history." + key), options);
  let scheduled = false;
  let pendingDrawerOpenAt = 0;
  let scope = "all";
  let keyedIndex = -1;
  let metaPromise = null;
  let lastScrollTop = 0;
  const metaById = new Map();
  const nativeSyncTimers = new Set();
  const activeRenameTeardowns = new Set();
  const scrollBound = new WeakSet();

  const touchLayout = () =>
    window.matchMedia && window.matchMedia("(max-width: 768px)").matches;

  function enabled() {
    return (
      settings.vcai_enabled === true && settings.vcai_history_enabled === true
    );
  }

  // Route eligibility comes from the shared core; the panel check stays so
  // the rail is also styled wherever Discourse AI renders it.
  function eligible() {
    return routeState().eligible || Boolean(document.querySelector(PANEL_SELECTOR));
  }

  function isPersistent() {
    const threshold = Number(settings.vcai_history_persistent_min_width) || 1100;
    return window.innerWidth >= threshold;
  }

  /* 1.2.0 answered "not allowed" whenever currentUser.groups was not
     populated, which is why the mobile sheet arrived with Pin as its only
     entry. Visibility is a convenience filter, never the security boundary —
     when the answer is genuinely unknown, show the control and let the server
     reject it if the member lacks rights. */
  function allowed(raw) {
    const names = parseGroups(raw);
    if (!names.length) {
      return true;
    }
    if (names.some((name) => EVERYONE.includes(name.toLowerCase()))) {
      return true;
    }
    const user = api.getCurrentUser?.();
    if (!user) {
      return false;
    }
    if (names.includes("staff") && (user.staff || user.admin || user.moderator)) {
      return true;
    }
    const groups = user.groups || user.get?.("groups");
    if (!Array.isArray(groups)) {
      return true;
    }
    const owned = groups.map((group) => group.name);
    return names.some((name) => name !== "staff" && owned.includes(name));
  }

  const mayDelete = () => allowed(settings.vcai_history_delete_allowed_groups);
  const mayRename = () => allowed(settings.vcai_history_rename_allowed_groups);
  const mayPin = () => settings.vcai_history_pinned_enabled !== false;

  /* ------------------------------------------------------------- pins -- */

  function pinKey() {
    const user = api.getCurrentUser?.();
    return "vcai_history_pins_" + (user?.username || "anon");
  }

  function readPins() {
    try {
      const raw = JSON.parse(localStorage.getItem(pinKey()) || "[]");
      return Array.isArray(raw) ? raw.filter((entry) => entry && entry.id) : [];
    } catch {
      return [];
    }
  }

  function writePins(list) {
    try {
      localStorage.setItem(pinKey(), JSON.stringify(list.slice(0, 24)));
    } catch {
      /* storage disabled — pins are a convenience, never a hard dependency */
    }
  }

  const isPinned = (id) => readPins().some((entry) => String(entry.id) === String(id));

  function togglePin(id, title, href) {
    const list = readPins();
    const index = list.findIndex((entry) => String(entry.id) === String(id));
    if (index >= 0) {
      list.splice(index, 1);
    } else {
      list.unshift({ id: String(id), title, href });
    }
    writePins(list);
  }

  function renamePin(id, title) {
    const list = readPins();
    const entry = list.find((item) => String(item.id) === String(id));
    if (entry) {
      entry.title = title;
      writePins(list);
    }
  }

  function dropPin(id) {
    writePins(readPins().filter((entry) => String(entry.id) !== String(id)));
  }

  /* ------------------------------------------------------------- meta -- */

  function loadMeta() {
    if (settings.vcai_history_row_meta_enabled === false) {
      return Promise.resolve();
    }
    if (metaPromise) {
      return metaPromise;
    }
    metaPromise = ajax("/discourse-ai/ai-bot/conversations.json", {
      data: { page: 0, per_page: 100 },
    })
      .then((result) => {
        const rows = result?.conversations || result?.topics || [];
        rows.forEach((entry) => {
          if (entry?.id) {
            metaById.set(String(entry.id), entry);
          }
        });
      })
      .catch(() => {
        /* decorative only */
      });
    return metaPromise;
  }

  function metaText(id) {
    const entry = metaById.get(String(id));
    if (!entry) {
      return null;
    }
    const parts = [];
    const count =
      entry.posts_count || entry.highest_post_number || entry.reply_count || 0;
    if (count) {
      parts.push(count + " MSG");
    }
    const age = shortAge(entry.bumped_at || entry.last_posted_at || entry.updated_at);
    if (age) {
      parts.push(age);
    }
    return parts.length ? parts.join(" · ") : null;
  }

  /* -------------------------------------------------------------- dom -- */

  function rowLabel(row) {
    return (
      row.querySelector(".sidebar-section-link-content-text") ||
      row.querySelector(".sidebar-section-link-content") ||
      row
    );
  }

  /* The row itself is an <a> inside an <li> wrapper that carries its own box.
     Hiding only the anchor left the wrapper in flow, which is what produced
     the scattered gaps when filtering. */
  function hideTarget(row) {
    return row.closest(".sidebar-section-link-wrapper") || row;
  }

  const rowHidden = (row) => hideTarget(row).classList.contains(HIDDEN_CLASS);

  function setRowHidden(row, hidden) {
    hideTarget(row).classList.toggle(HIDDEN_CLASS, hidden);
    row.classList.toggle(HIDDEN_CLASS, hidden);
  }

  function topicId(row) {
    const classMatch = row.className.match(/ai-conversation-(\d+)/);
    if (classMatch) {
      return classMatch[1];
    }
    const href = (row.closest("a") || row.querySelector("a"))?.getAttribute("href");
    return href?.match(/\/t\/(?:[^/]+\/)?(\d+)/)?.[1] || null;
  }

  const currentTopicId = () =>
    window.location.pathname.match(/\/t\/(?:[^/]+\/)?(\d+)/)?.[1] || null;

  const visibleRows = (panel) =>
    [...panel.querySelectorAll(ROW_SELECTOR)].filter((row) => !rowHidden(row));

  /* ---------------------------------------------------------- headers -- */

  function decorateHeaders(panel) {
    panel.querySelectorAll(HEADER_SELECTOR).forEach((header) => {
      if (!header.querySelector(".vcai-history-rule")) {
        const rule = document.createElement("span");
        rule.className = "vcai-history-rule";
        rule.setAttribute("aria-hidden", "true");
        header.appendChild(rule);
      }
      if (!header.querySelector(".vcai-history-count")) {
        const count = document.createElement("span");
        count.className = "vcai-history-count";
        count.setAttribute("aria-hidden", "true");
        header.appendChild(count);
      }
    });
  }

  function headerHideTarget(header) {
    return header.closest(".sidebar-section-header-wrapper") || header;
  }

  function updateHeaders(panel) {
    const sections = [...panel.querySelectorAll(".sidebar-section")];
    sections.forEach((section) => {
      const header = section.querySelector(HEADER_SELECTOR);
      const rows = [...section.querySelectorAll(ROW_SELECTOR)];
      if (!header) {
        return;
      }
      const shown = rows.filter((row) => !rowHidden(row));
      const count = header.querySelector(".vcai-history-count");
      if (count) {
        count.textContent = shown.length ? String(shown.length) : "";
      }
      if (rows.length) {
        headerHideTarget(header).classList.toggle(HIDDEN_CLASS, shown.length === 0);
      }
    });

    if (sections.length) {
      return;
    }

    const headers = [...panel.querySelectorAll(HEADER_SELECTOR)];
    headers.forEach((header, index) => {
      const nextHeader = headers[index + 1];
      let sibling =
        header.parentElement?.nextElementSibling || header.nextElementSibling;
      let hasVisibleRow = false;
      while (sibling && sibling !== nextHeader && !sibling.contains?.(nextHeader)) {
        const row = sibling.matches?.(ROW_SELECTOR)
          ? sibling
          : sibling.querySelector?.(ROW_SELECTOR);
        if (row && !rowHidden(row)) {
          hasVisibleRow = true;
          break;
        }
        sibling = sibling.nextElementSibling;
      }
      headerHideTarget(header).classList.toggle(HIDDEN_CLASS, !hasVisibleRow);
    });
  }

  /* --------------------------------------------------------- filtering -- */

  function filterRows(panel, rawQuery) {
    const query = String(rawQuery || "").trim().toLocaleLowerCase();
    panel.querySelectorAll(ROW_SELECTOR).forEach((row) => {
      const label = rowLabel(row).textContent.trim().toLocaleLowerCase();
      const matchesQuery = !query || label.includes(query);
      const matchesScope = scope !== "pinned" || isPinned(topicId(row));
      setRowHidden(row, !(matchesQuery && matchesScope));
    });
    updateHeaders(panel);

    const shelf = document.getElementById(SHELF_ID);
    if (shelf) {
      shelf.classList.toggle(HIDDEN_CLASS, scope === "pinned" || Boolean(query));
    }

    const clear = document.querySelector(".vcai-history-search__clear");
    if (clear) {
      clear.classList.toggle(HIDDEN_CLASS, !query);
    }

    const empty = panel.querySelector(".vcai-history-empty");
    if (empty) {
      empty.textContent =
        scope === "pinned" && !query ? t("empty_pinned") : t("empty_filter");
      empty.classList.toggle(HIDDEN_CLASS, visibleRows(panel).length > 0);
    }

    keyedIndex = -1;
    panel
      .querySelectorAll("." + KEYED_CLASS)
      .forEach((row) => row.classList.remove(KEYED_CLASS));
  }

  const currentQuery = () => document.getElementById(FILTER_ID)?.value || "";
  const reflow = (panel) => filterRows(panel, currentQuery());

  /* ------------------------------------------------------ search + chips -- */

  function mountSearch(panel) {
    if (settings.vcai_history_filter_enabled === false) {
      document.getElementById(SEARCH_ID)?.remove();
      return;
    }

    let wrapper = document.getElementById(SEARCH_ID);
    if (!wrapper) {
      wrapper = document.createElement("div");
      wrapper.id = SEARCH_ID;
      wrapper.className = "vcai-history-search";

      const iconSpan = document.createElement("span");
      iconSpan.className = "vcai-history-search__icon";
      iconSpan.appendChild(icon("search", 1.8));

      const input = document.createElement("input");
      input.id = FILTER_ID;
      input.className = "vcai-history-search__input";
      input.type = "search";
      input.autocomplete = "off";
      input.placeholder = t("filter_placeholder");
      input.setAttribute("aria-label", t("filter_placeholder"));

      const clear = document.createElement("button");
      clear.type = "button";
      clear.className = "vcai-history-search__clear " + HIDDEN_CLASS;
      clear.appendChild(icon("close", 2.2));
      clear.setAttribute("aria-label", t("close_label"));
      clear.addEventListener("click", (event) => {
        event.preventDefault();
        input.value = "";
        filterRows(panel, "");
        input.focus();
      });

      input.addEventListener("input", () => filterRows(panel, input.value));
      input.addEventListener("keydown", (event) => {
        event.stopPropagation();
        if (event.key === "Escape") {
          input.value = "";
          filterRows(panel, "");
          input.blur();
        } else if (event.key === "ArrowDown") {
          event.preventDefault();
          moveKeyed(panel, 1);
        }
      });

      wrapper.append(iconSpan, input, clear);
      panel.insertBefore(wrapper, panel.firstChild);
    }

    const input = document.getElementById(FILTER_ID);
    const total = panel.querySelectorAll(ROW_SELECTOR).length;
    if (input && total) {
      const label = t("filter_placeholder_counted", { count: total });
      input.placeholder = label;
      input.setAttribute("aria-label", label);
    }
  }

  function mountScopes(panel) {
    const pins = readPins();
    let wrapper = document.getElementById(SCOPES_ID);

    if (!mayPin() || !pins.length) {
      wrapper?.remove();
      scope = "all";
      return;
    }

    if (!wrapper) {
      wrapper = document.createElement("div");
      wrapper.id = SCOPES_ID;
      wrapper.className = "vcai-history-scopes";
      wrapper.setAttribute("role", "group");

      ["all", "pinned"].forEach((name) => {
        const chip = document.createElement("button");
        chip.type = "button";
        chip.className = "vcai-history-scope";
        chip.dataset.scope = name;
        chip.addEventListener("click", (event) => {
          event.preventDefault();
          scope = name;
          syncScopes(panel);
          reflow(panel);
        });
        wrapper.appendChild(chip);
      });

      const search = document.getElementById(SEARCH_ID);
      panel.insertBefore(wrapper, search ? search.nextSibling : panel.firstChild);
    }

    syncScopes(panel);
  }

  function syncScopes(panel) {
    const wrapper = document.getElementById(SCOPES_ID);
    if (!wrapper) {
      return;
    }
    const total = panel.querySelectorAll(ROW_SELECTOR).length;
    const pinned = readPins().length;
    wrapper.querySelectorAll(".vcai-history-scope").forEach((chip) => {
      const name = chip.dataset.scope;
      chip.textContent =
        name === "all"
          ? t("all_label") + " " + total
          : t("pinned_label") + " " + pinned;
      chip.setAttribute("aria-pressed", String(scope === name));
    });
  }

  /* ------------------------------------------------------------ shelf -- */

  function mountShelf(panel) {
    const pins = mayPin() ? readPins() : [];
    let shelf = document.getElementById(SHELF_ID);

    if (!pins.length) {
      shelf?.remove();
      return;
    }

    if (!shelf) {
      shelf = document.createElement("div");
      shelf.id = SHELF_ID;
      shelf.className = "vcai-history-shelf";
      const anchor =
        document.getElementById(SCOPES_ID) || document.getElementById(SEARCH_ID);
      panel.insertBefore(shelf, anchor ? anchor.nextSibling : panel.firstChild);
    }

    shelf.textContent = "";

    const header = document.createElement("div");
    header.className = "vcai-history-shelf__header";
    header.appendChild(icon("starFilled", 0));
    const headerText = document.createElement("span");
    headerText.textContent = t("pinned_heading");
    header.appendChild(headerText);
    const rule = document.createElement("span");
    rule.className = "vcai-history-rule";
    header.appendChild(rule);
    shelf.appendChild(header);

    const active = currentTopicId();
    pins.forEach((entry) => {
      const link = document.createElement("a");
      link.className = "vcai-history-shelf__link";
      link.href = entry.href || "/t/-/" + entry.id;
      link.title = entry.title || "";
      if (String(entry.id) === String(active)) {
        link.classList.add(ACTIVE_CLASS);
      }

      const title = document.createElement("span");
      title.textContent = entry.title || "";
      link.appendChild(title);

      const meta = metaText(entry.id);
      if (meta) {
        const metaSpan = document.createElement("span");
        metaSpan.className = "vcai-history-meta";
        metaSpan.textContent = meta;
        link.appendChild(metaSpan);
      }

      link.appendChild(
        buildActionButton(link, entry.id, () => entry.title || "", link.href)
      );
      shelf.appendChild(link);
    });
  }

  /* ------------------------------------------------------------ toast -- */

  function dismissToast() {
    document.getElementById(TOAST_ID)?.remove();
  }

  function showToast(message, undoLabel, onUndo) {
    dismissToast();
    const seconds = Number(settings.vcai_history_undo_window_seconds ?? 8);
    const toast = document.createElement("div");
    toast.id = TOAST_ID;
    toast.className = "vcai-history-toast";
    toast.setAttribute("role", "status");

    const text = document.createElement("span");
    text.textContent = message;
    toast.appendChild(text);

    if (onUndo && seconds > 0) {
      const undo = document.createElement("button");
      undo.type = "button";
      undo.className = "vcai-history-toast__undo";
      undo.textContent = undoLabel;
      undo.addEventListener("click", () => {
        dismissToast();
        onUndo();
      });
      toast.appendChild(undo);
    }

    document.body.appendChild(toast);
    if (seconds > 0) {
      setTimeout(() => {
        if (document.getElementById(TOAST_ID) === toast) {
          toast.remove();
        }
      }, seconds * 1000);
    }
  }

  /* ----------------------------------------------------------- rename -- */

  function neutralizeRow(row) {
    const anchor = row.closest("a") || (row.matches("a") ? row : null);
    if (!anchor) {
      return () => {};
    }
    const href = anchor.getAttribute("href");
    const guard = (event) => {
      if (!event.target.closest(".vcai-history-rename")) {
        event.preventDefault();
        event.stopPropagation();
      }
    };
    anchor.removeAttribute("href");
    anchor.addEventListener("click", guard, true);
    return () => {
      anchor.removeEventListener("click", guard, true);
      if (href !== null) {
        anchor.setAttribute("href", href);
      }
    };
  }

  function beginRename(row, id) {
    if (row.classList.contains("vcai-history-row--renaming")) {
      return;
    }
    const label =
      row.querySelector(".sidebar-section-link-content-text") ||
      row.querySelector(".sidebar-section-link-content") ||
      row.querySelector("span:not(.vcai-history-meta)");
    if (!label) {
      return;
    }

    const original = label.textContent.trim();
    const restoreAnchor = neutralizeRow(row);
    const originalDisplay = label.style.display;

    row.classList.add("vcai-history-row--renaming");
    label.style.display = "none";

    const editor = document.createElement("span");
    editor.className = "vcai-history-rename";

    const input = document.createElement("input");
    input.className = "vcai-history-rename__input";
    input.type = "text";
    input.value = original;
    input.setAttribute("aria-label", t("rename_label"));

    const save = document.createElement("button");
    save.className = "vcai-history-rename__save";
    save.type = "button";
    save.appendChild(icon("check", 2.2));
    save.setAttribute("aria-label", t("rename_save_label"));

    const cancel = document.createElement("button");
    cancel.className = "vcai-history-rename__cancel";
    cancel.type = "button";
    cancel.appendChild(icon("close", 2));
    cancel.setAttribute("aria-label", t("rename_cancel_label"));

    editor.append(input, save, cancel);
    label.parentElement?.insertBefore(editor, label);

    const teardown = (newTitle) => {
      activeRenameTeardowns.delete(teardown);
      restoreAnchor();
      editor.remove();
      row.classList.remove("vcai-history-row--renaming");
      label.style.display = originalDisplay;
      if (newTitle) {
        label.textContent = newTitle;
        renamePin(id, newTitle);
        const panel = document.querySelector(PANEL_SELECTOR);
        if (panel) {
          mountShelf(panel);
        }
      }
    };
    activeRenameTeardowns.add(teardown);

    const commit = async () => {
      const title = input.value.trim();
      if (!title) {
        input.focus();
        return;
      }
      if (title === original) {
        teardown();
        return;
      }
      save.disabled = true;
      cancel.disabled = true;
      try {
        await ajax("/t/-/" + id + ".json", { type: "PUT", data: { title } });
        teardown(title);
      } catch (error) {
        // eslint-disable-next-line no-console
        console.error("[vcai-history] Rename failed", error);
        showToast(t("rename_failed"));
        teardown();
      }
    };

    editor.addEventListener("mousedown", (event) => event.stopPropagation());
    editor.addEventListener("click", (event) => {
      event.preventDefault();
      event.stopPropagation();
    });
    save.addEventListener("click", commit);
    cancel.addEventListener("click", () => teardown());
    input.addEventListener("keydown", (event) => {
      event.stopPropagation();
      if (event.key === "Enter") {
        event.preventDefault();
        commit();
      } else if (event.key === "Escape") {
        event.preventDefault();
        teardown();
      }
    });

    input.focus();
    input.select();
  }

  /* ----------------------------------------------------------- delete -- */

  async function performDelete(row, id) {
    const panel = document.querySelector(PANEL_SELECTOR);
    const node = hideTarget(row);
    const parent = node.parentElement;
    const next = node.nextSibling;
    const wasCurrent = currentTopicId() === String(id);

    try {
      await ajax("/t/" + id + ".json", { type: "DELETE" });
    } catch (error) {
      // eslint-disable-next-line no-console
      console.error("[vcai-history] Delete failed", error);
      showToast(t("delete_failed"));
      return;
    }

    row.classList.add("vcai-history-row--removing");
    setTimeout(() => {
      node.remove();
      if (panel) {
        reflow(panel);
        syncScopes(panel);
      }
    }, 180);

    dropPin(id);
    if (panel) {
      mountShelf(panel);
      syncScopes(panel);
    }

    if (wasCurrent) {
      DiscourseURL.routeTo("/discourse-ai/ai-bot/conversations");
    }

    showToast(t("deleted_toast"), t("undo_label"), async () => {
      try {
        await ajax("/t/" + id + "/recover", { type: "PUT" });
        if (parent && !node.isConnected) {
          row.classList.remove("vcai-history-row--removing");
          parent.insertBefore(node, next);
          if (panel) {
            reflow(panel);
            syncScopes(panel);
          }
        }
      } catch (error) {
        // eslint-disable-next-line no-console
        console.error("[vcai-history] Undo failed", error);
        showToast(t("undo_failed"));
      }
    });
  }

  /* ------------------------------------------------------ overflow menu -- */

  function closeMenu() {
    const menu = document.getElementById(MENU_ID);
    const opener = menu?.__vcaiOpener;
    menu?.remove();
    document.getElementById(SCRIM_ID)?.remove();
    opener?.setAttribute("aria-expanded", "false");
  }

  function menuHost() {
    const panel = document.querySelector(PANEL_SELECTOR);
    return (
      panel?.closest(".hamburger-panel .menu-panel") ||
      panel?.closest(".menu-panel.slide-in") ||
      panel?.closest(".sidebar-wrapper") ||
      document.body
    );
  }

  function menuItem(iconName, label, danger, onSelect) {
    const item = document.createElement("button");
    item.type = "button";
    item.className =
      "vcai-history-menu__item" + (danger ? " vcai-history-menu__item--danger" : "");
    item.appendChild(icon(iconName, 1.7));
    const text = document.createElement("span");
    text.textContent = label;
    item.appendChild(text);
    item.addEventListener("click", (event) => {
      event.preventDefault();
      event.stopPropagation();
      closeMenu();
      onSelect();
    });
    return item;
  }

  function openMenu(button, row, id, getTitle, href) {
    if (document.getElementById(MENU_ID)?.__vcaiOwner === row) {
      closeMenu();
      return;
    }
    closeMenu();

    const host = menuHost();
    const menu = document.createElement("div");
    menu.id = MENU_ID;
    menu.className = "vcai-history-menu";
    menu.setAttribute("role", "menu");
    menu.__vcaiOwner = row;
    menu.__vcaiOpener = button;

    const heading = document.createElement("div");
    heading.className = "vcai-history-menu__heading";
    heading.textContent = t("actions_heading");
    menu.appendChild(heading);

    if (mayRename()) {
      menu.appendChild(
        menuItem("pencil", t("rename_label"), false, () => beginRename(row, id))
      );
    }

    if (mayPin()) {
      const pinned = isPinned(id);
      menu.appendChild(
        menuItem(
          pinned ? "starFilled" : "star",
          pinned ? t("unpin_label") : t("pin_label"),
          false,
          () => {
            togglePin(id, getTitle(), href);
            const panel = document.querySelector(PANEL_SELECTOR);
            if (panel) {
              mountScopes(panel);
              mountShelf(panel);
              decorateRows(panel);
              reflow(panel);
            }
          }
        )
      );
    }

    if (mayDelete()) {
      if (menu.querySelector(".vcai-history-menu__item")) {
        const separator = document.createElement("div");
        separator.className = "vcai-history-menu__sep";
        menu.appendChild(separator);
      }
      menu.appendChild(
        menuItem("trash", t("delete_label"), true, () => performDelete(row, id))
      );
    }

    const scrim = document.createElement("button");
    scrim.id = SCRIM_ID;
    scrim.type = "button";
    scrim.className = "vcai-history-menu-scrim";
    scrim.setAttribute("aria-label", t("close_label"));
    scrim.addEventListener("pointerdown", (event) => {
      event.preventDefault();
      event.stopPropagation();
      closeMenu();
    });
    scrim.addEventListener("click", (event) => {
      event.preventDefault();
      event.stopPropagation();
    });

    menu.addEventListener("pointerdown", (event) => event.stopPropagation());
    menu.addEventListener("click", (event) => event.stopPropagation());

    host.appendChild(scrim);
    host.appendChild(menu);
    button.setAttribute("aria-expanded", "true");

    if (!touchLayout()) {
      const rect = button.getBoundingClientRect();
      const width = menu.offsetWidth || 196;
      const height = menu.offsetHeight || 170;
      const left = Math.min(
        Math.max(8, rect.right - width),
        window.innerWidth - width - 8
      );
      const top =
        rect.bottom + height + 8 > window.innerHeight
          ? Math.max(8, rect.top - height - 6)
          : rect.bottom + 6;
      menu.style.left = left + "px";
      menu.style.top = top + "px";
    }

    menu.querySelector(".vcai-history-menu__item")?.focus();
  }

  /* ------------------------------------------------------- row actions -- */

  function buildActionButton(row, id, getTitle, href) {
    const button = document.createElement("button");
    button.type = "button";
    button.className = "vcai-history-action";
    button.appendChild(icon("dots", 0));
    button.setAttribute("aria-label", t("actions_label"));
    button.setAttribute("title", t("actions_label"));
    button.setAttribute("aria-haspopup", "menu");
    button.setAttribute("aria-expanded", "false");

    const swallow = (event) => {
      event.preventDefault();
      event.stopPropagation();
    };
    button.addEventListener("pointerdown", swallow);
    button.addEventListener("mousedown", swallow);
    button.addEventListener("touchstart", (event) => event.stopPropagation(), {
      passive: true,
    });
    button.addEventListener("click", (event) => {
      event.preventDefault();
      event.stopPropagation();
      openMenu(button, row, id, getTitle, href);
    });

    return button;
  }

  function decorateRows(panel) {
    const showMeta = settings.vcai_history_row_meta_enabled !== false;
    const active = currentTopicId();
    const anyAction = mayRename() || mayDelete() || mayPin();

    panel.querySelectorAll(ROW_SELECTOR).forEach((row) => {
      const id = topicId(row);
      if (!id) {
        return;
      }

      row.dataset.vcaiId = id;
      const label = rowLabel(row);
      const isActive = active && String(active) === String(id);
      row.classList.toggle(ACTIVE_CLASS, Boolean(isActive));

      let meta = row.querySelector(".vcai-history-meta");
      const text = showMeta ? metaText(id) : null;
      if (isActive || text) {
        if (!meta) {
          meta = document.createElement("span");
          meta.className = "vcai-history-meta";
          row.appendChild(meta);
        }
        meta.textContent = "";
        if (isActive) {
          const dot = document.createElement("span");
          dot.className = "vcai-history-dot";
          meta.appendChild(dot);
          meta.appendChild(
            document.createTextNode(t("active_label") + (text ? " · " + text : ""))
          );
        } else {
          meta.textContent = text;
        }
      } else if (meta) {
        meta.remove();
      }

      const pinned = mayPin() && isPinned(id);
      let badge = row.querySelector(".vcai-history-pin-badge");
      if (pinned && !badge) {
        badge = document.createElement("span");
        badge.className = "vcai-history-pin-badge";
        badge.setAttribute("aria-hidden", "true");
        badge.appendChild(icon("starFilled", 0));
        row.appendChild(badge);
      } else if (!pinned && badge) {
        badge.remove();
      }

      if (anyAction && !row.querySelector(".vcai-history-action")) {
        row.appendChild(
          buildActionButton(
            row,
            id,
            () => label.textContent.trim(),
            row.getAttribute("href") || "/t/-/" + id
          )
        );
      }

      const metaNode = row.querySelector(".vcai-history-meta");
      const actionNode = row.querySelector(".vcai-history-action");
      if (metaNode && actionNode) {
        row.insertBefore(metaNode, actionNode);
      }
    });
  }

  function mountEmptyState(panel) {
    if (panel.querySelector(".vcai-history-empty")) {
      return;
    }
    const empty = document.createElement("div");
    empty.className = "vcai-history-empty " + HIDDEN_CLASS;
    empty.textContent = t("empty_filter");
    panel.appendChild(empty);
  }

  function mountHint(panel) {
    if (settings.vcai_history_keyboard_enabled === false) {
      document.getElementById(HINT_ID)?.remove();
      return;
    }
    if (document.getElementById(HINT_ID)) {
      return;
    }
    const hint = document.createElement("div");
    hint.id = HINT_ID;
    hint.className = "vcai-history-hint";
    hint.textContent = t("keyboard_hint");
    panel.appendChild(hint);
  }

  function mountNewQuestionHint() {
    const button = document.querySelector(".ai-new-question-button");
    if (!button || button.querySelector(".vcai-history-kbd") || touchLayout()) {
      return;
    }
    const kbd = document.createElement("span");
    kbd.className = "vcai-history-kbd";
    kbd.setAttribute("aria-hidden", "true");
    kbd.textContent = "⌘K";
    button.appendChild(kbd);
  }

  /* ------------------------------------------- mobile scroll chrome -- */

  function chromeNodes() {
    const nodes = [];
    const wrapper = document.querySelector(".ai-new-question-button__wrapper");
    if (wrapper) {
      nodes.push(wrapper);
    }
    const extra = String(settings.vcai_history_mobile_hide_chrome_selectors || "").trim();
    if (extra) {
      try {
        document.querySelectorAll(extra).forEach((node) => nodes.push(node));
      } catch {
        /* an invalid selector in settings must never break the rail */
      }
    }
    return nodes;
  }

  function markChrome() {
    if (settings.vcai_history_mobile_hide_chrome_on_scroll === false) {
      document
        .querySelectorAll("." + CHROME_CLASS)
        .forEach((node) => node.classList.remove(CHROME_CLASS));
      document.body.classList.remove(CHROME_HIDDEN_CLASS);
      return;
    }
    chromeNodes().forEach((node) => node.classList.add(CHROME_CLASS));
  }

  function bindScrollHide(panel) {
    if (settings.vcai_history_mobile_hide_chrome_on_scroll === false) {
      return;
    }
    const targets = [panel, panel.closest(".sidebar-container"), panel.parentElement]
      .filter(Boolean)
      .filter((node) => !scrollBound.has(node));

    targets.forEach((node) => {
      scrollBound.add(node);
      node.addEventListener(
        "scroll",
        () => {
          if (!touchLayout()) {
            document.body.classList.remove(CHROME_HIDDEN_CLASS);
            return;
          }
          const top = node.scrollTop;
          if (Math.abs(top - lastScrollTop) < 6) {
            return;
          }
          const goingDown = top > lastScrollTop;
          lastScrollTop = top;
          document.body.classList.toggle(
            CHROME_HIDDEN_CLASS,
            goingDown && top > 24
          );
        },
        { passive: true }
      );
    });
  }

  /* --------------------------------------------------------- keyboard -- */

  function moveKeyed(panel, delta) {
    const rows = visibleRows(panel);
    if (!rows.length) {
      return;
    }
    rows.forEach((row) => row.classList.remove(KEYED_CLASS));
    keyedIndex = Math.min(
      rows.length - 1,
      Math.max(0, (keyedIndex === -1 ? (delta > 0 ? -1 : 0) : keyedIndex) + delta)
    );
    const row = rows[keyedIndex];
    row.classList.add(KEYED_CLASS);
    row.focus?.();
  }

  function handleGlobalKeys(event) {
    if (settings.vcai_history_keyboard_enabled === false) {
      return;
    }
    const panel = document.querySelector(PANEL_SELECTOR);
    if (!panel || !eligible()) {
      return;
    }
    const typing = event.target?.closest?.(
      "input, textarea, select, [contenteditable='true']"
    );

    if (event.key === "/" && !typing) {
      const input = document.getElementById(FILTER_ID);
      if (input) {
        event.preventDefault();
        input.focus();
        input.select();
      }
      return;
    }

    if (typing) {
      return;
    }

    if (event.key === "ArrowDown" || event.key === "ArrowUp") {
      if (!panel.contains(document.activeElement) && keyedIndex === -1) {
        return;
      }
      event.preventDefault();
      moveKeyed(panel, event.key === "ArrowDown" ? 1 : -1);
    } else if (event.key === "Enter" && keyedIndex >= 0) {
      const href = visibleRows(panel)[keyedIndex]?.getAttribute("href");
      if (href) {
        event.preventDefault();
        DiscourseURL.routeTo(href);
      }
    }
  }

  /* ------------------------------------------------------ drawer shell -- */

  function reflectDrawerState(open, announce = false) {
    if (open && !isPersistent() && announce) {
      window.dispatchEvent(
        new CustomEvent("vcai:drawer-opening", { detail: { owner: "history" } })
      );
    }
    document.body.classList.toggle(OPEN_CLASS, open && !isPersistent());
    const toggle = document.getElementById(TOGGLE_ID);
    toggle?.setAttribute("aria-expanded", String(open && !isPersistent()));
    toggle?.setAttribute(
      "aria-label",
      open && !isPersistent() ? t("close_label") : t("toggle_label")
    );
  }

  const setDrawer = (open) => reflectDrawerState(open, open);

  function nativeMobileMenu(panel = document.querySelector(PANEL_SELECTOR)) {
    return (
      panel?.closest(".hamburger-panel .menu-panel") ||
      panel?.closest(".menu-panel.slide-in") ||
      null
    );
  }

  function nativeMenuIsOpen(menu) {
    if (!menu) {
      return false;
    }
    const rect = menu.getBoundingClientRect();
    const style = window.getComputedStyle(menu);
    return (
      style.display !== "none" &&
      style.visibility !== "hidden" &&
      rect.width > 0 &&
      rect.right > 1 &&
      rect.left < window.innerWidth - 1
    );
  }

  function syncNativeDrawerState() {
    if (!enabled() || !eligible() || isPersistent()) {
      document.body.classList.remove(NATIVE_MOBILE_CLASS);
      return;
    }
    const wasNative = document.body.classList.contains(NATIVE_MOBILE_CLASS);
    const menu = nativeMobileMenu();
    if (menu) {
      document.body.classList.add(NATIVE_MOBILE_CLASS);
      reflectDrawerState(nativeMenuIsOpen(menu), false);
      return;
    }
    if (wasNative) {
      reflectDrawerState(false, false);
    }
    document.body.classList.remove(NATIVE_MOBILE_CLASS);
  }

  function scheduleNativeSync(delay = 0) {
    const timer = setTimeout(() => {
      nativeSyncTimers.delete(timer);
      syncNativeDrawerState();
    }, delay);
    nativeSyncTimers.add(timer);
  }

  function scheduleNativeTransitionSync() {
    scheduleNativeSync(0);
    scheduleNativeSync(80);
    scheduleNativeSync(280);
  }

  function clickNativeToggle(preferMobile = false) {
    const chain = preferMobile
      ? ["#toggle-hamburger-menu", ".hamburger-dropdown button", ".btn-sidebar-toggle"]
      : NATIVE_TOGGLE_CHAIN;
    for (const selector of chain) {
      const control = document.querySelector(selector);
      if (control) {
        control.click();
        return true;
      }
    }
    return false;
  }

  function closeNativeMenu() {
    const cloak = document.querySelector(".header-cloak");
    if (cloak) {
      const PointerEventConstructor = window.PointerEvent || window.MouseEvent;
      cloak.dispatchEvent(
        new PointerEventConstructor("pointerdown", {
          bubbles: true,
          cancelable: true,
          composed: true,
          button: 0,
          pointerType: "touch",
          isPrimary: true,
        })
      );
      return true;
    }
    return clickNativeToggle(true);
  }

  function toggleDrawer() {
    const panel = document.querySelector(PANEL_SELECTOR);
    if (!panel) {
      pendingDrawerOpenAt = Date.now();
      reflectDrawerState(true, true);
      clickNativeToggle(true);
      setTimeout(scheduleApply, 120);
      scheduleNativeTransitionSync();
      return;
    }
    const nativeMenu = nativeMobileMenu(panel);
    if (nativeMenu) {
      const opening = !nativeMenuIsOpen(nativeMenu);
      reflectDrawerState(opening, opening);
      if (opening) {
        clickNativeToggle(true);
      } else {
        closeNativeMenu();
      }
      scheduleNativeTransitionSync();
      return;
    }
    setDrawer(!document.body.classList.contains(OPEN_CLASS));
  }

  function closeDrawer() {
    const menu = nativeMobileMenu();
    if (menu && nativeMenuIsOpen(menu)) {
      reflectDrawerState(false, false);
      closeNativeMenu();
      scheduleNativeTransitionSync();
      return;
    }
    setDrawer(false);
  }

  function mountDrawerControls() {
    if (!document.getElementById(TOGGLE_ID)) {
      const toggle = document.createElement("button");
      toggle.id = TOGGLE_ID;
      toggle.className = "vcai-history-toggle";
      toggle.type = "button";
      toggle.innerHTML = '<span aria-hidden="true">›</span>';
      toggle.setAttribute("aria-controls", "main-outlet-wrapper");
      toggle.setAttribute("aria-label", t("toggle_label"));
      toggle.setAttribute("aria-expanded", "false");
      toggle.addEventListener("click", toggleDrawer);
      document.body.appendChild(toggle);
    }
    if (!document.getElementById(BACKDROP_ID)) {
      const backdrop = document.createElement("button");
      backdrop.id = BACKDROP_ID;
      backdrop.className = "vcai-history-backdrop";
      backdrop.type = "button";
      backdrop.setAttribute("aria-label", t("close_label"));
      backdrop.addEventListener("click", closeDrawer);
      document.body.appendChild(backdrop);
    }
  }

  function removeInjected() {
    [...activeRenameTeardowns].forEach((teardown) => teardown());
    closeMenu();
    dismissToast();
    document.getElementById(TOGGLE_ID)?.remove();
    document.getElementById(BACKDROP_ID)?.remove();
    document.getElementById(SEARCH_ID)?.remove();
    document.getElementById(SCOPES_ID)?.remove();
    document.getElementById(SHELF_ID)?.remove();
    document.getElementById(HINT_ID)?.remove();
    document
      .querySelectorAll(
        ".vcai-history-action, .vcai-history-meta, .vcai-history-pin-badge, .vcai-history-rule, .vcai-history-count, .vcai-history-empty, .vcai-history-kbd"
      )
      .forEach((node) => node.remove());
    document.querySelectorAll("." + HIDDEN_CLASS).forEach((node) => {
      node.classList.remove(HIDDEN_CLASS);
    });
    document
      .querySelectorAll("." + ACTIVE_CLASS + ", ." + KEYED_CLASS + ", ." + CHROME_CLASS)
      .forEach((node) =>
        node.classList.remove(ACTIVE_CLASS, KEYED_CLASS, CHROME_CLASS)
      );
    nativeSyncTimers.forEach((timer) => clearTimeout(timer));
    nativeSyncTimers.clear();
    document.body.classList.remove(
      ROOT_CLASS,
      PERSISTENT_CLASS,
      OPEN_CLASS,
      NATIVE_MOBILE_CLASS,
      CHROME_HIDDEN_CLASS
    );
    document.body.style.removeProperty("--vcai-history-width");
  }

  /* ------------------------------------------------------------ apply -- */

  function apply() {
    if (!enabled() || !eligible()) {
      removeInjected();
      return;
    }

    document.body.classList.add(ROOT_CLASS);
    document.body.style.setProperty(
      "--vcai-history-width",
      (Number(settings.vcai_history_width) || 380) + "px"
    );

    const persistent = isPersistent();
    document.body.classList.toggle(PERSISTENT_CLASS, persistent);
    if (persistent) {
      setDrawer(false);
      document.body.classList.remove(NATIVE_MOBILE_CLASS, CHROME_HIDDEN_CLASS);
    }

    mountDrawerControls();
    mountNewQuestionHint();
    markChrome();

    const panel = document.querySelector(PANEL_SELECTOR);
    if (panel) {
      const menu = !persistent ? nativeMobileMenu(panel) : null;
      document.body.classList.toggle(NATIVE_MOBILE_CLASS, Boolean(menu));

      mountSearch(panel);
      mountScopes(panel);
      mountShelf(panel);
      decorateHeaders(panel);
      decorateRows(panel);
      mountEmptyState(panel);
      mountHint(panel);
      bindScrollHide(panel);
      reflow(panel);

      loadMeta().then(() => {
        const fresh = document.querySelector(PANEL_SELECTOR);
        if (fresh) {
          decorateRows(fresh);
          mountShelf(fresh);
        }
      });

      if (pendingDrawerOpenAt) {
        const fresh = Date.now() - pendingDrawerOpenAt < 3000;
        pendingDrawerOpenAt = 0;
        if (fresh && menu) {
          reflectDrawerState(true, true);
          scheduleNativeTransitionSync();
        } else if (fresh && !persistent) {
          setDrawer(true);
        }
      } else if (menu) {
        syncNativeDrawerState();
      }
    } else if (!pendingDrawerOpenAt) {
      reflectDrawerState(false, false);
      document.body.classList.remove(NATIVE_MOBILE_CLASS);
    }
  }

  function scheduleApply() {
    if (scheduled) {
      return;
    }
    scheduled = true;
    nextPaint(() => {
      scheduled = false;
      apply();
    });
  }

  api.onPageChange(() => {
    pendingDrawerOpenAt = 0;
    keyedIndex = -1;
    lastScrollTop = 0;
    closeMenu();
    reflectDrawerState(false, false);
    document.body.classList.remove(NATIVE_MOBILE_CLASS, CHROME_HIDDEN_CLASS);
  });

  // Applying is driven by the shared route-state core, which publishes on
  // page change and whenever the Discourse AI route classes land on <body>.
  ensureRouteState(api);
  onRouteState(() => {
    scheduleApply();
    setTimeout(scheduleApply, 150);
  });

  // The header History control (header-controls module) drives the drawer
  // through this event; this module stays the single owner of drawer state.
  window.addEventListener("vcai:history:toggle", () => {
    if (enabled() && eligible()) {
      toggleDrawer();
    }
  });

  window.addEventListener("resize", scheduleApply, { passive: true });
  window.addEventListener("resize", closeMenu, { passive: true });

  document.addEventListener("keydown", (event) => {
    if (event.key === "Escape") {
      if (document.getElementById(MENU_ID)) {
        closeMenu();
        return;
      }
      if (document.body.classList.contains(OPEN_CLASS)) {
        if (nativeMobileMenu()) {
          scheduleNativeTransitionSync();
        } else {
          closeDrawer();
        }
      }
      return;
    }
    handleGlobalKeys(event);
  });

  document.addEventListener(
    "click",
    () => {
      if (document.body.classList.contains(NATIVE_MOBILE_CLASS)) {
        scheduleNativeTransitionSync();
      }
    },
    { passive: true }
  );

  window.addEventListener("vcai:drawer-opening", (event) => {
    if (event.detail?.owner !== "history") {
      closeDrawer();
    }
  });

  const observer = new MutationObserver((mutations) => {
    if (!enabled()) {
      return;
    }
    for (const mutation of mutations) {
      for (const node of mutation.addedNodes) {
        if (node.nodeType !== Node.ELEMENT_NODE) {
          continue;
        }
        if (
          node.matches?.(PANEL_SELECTOR) ||
          node.querySelector?.(PANEL_SELECTOR) ||
          node.matches?.(ROW_SELECTOR) ||
          node.querySelector?.(ROW_SELECTOR)
        ) {
          scheduleApply();
          return;
        }
      }
    }
  });

  observer.observe(document.body, { childList: true, subtree: true });
  scheduleApply();
});
