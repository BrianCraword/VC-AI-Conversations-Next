import { apiInitializer } from "discourse/lib/api";
import { ajax } from "discourse/lib/ajax";
import { i18n } from "discourse-i18n";
import {
  ensureRouteState,
  nextPaint,
  onRouteState,
  routeState,
} from "../lib/vcai-route-state";

const ROOT_CLASS = "vcai-memory";
const OPEN_CLASS = "vcai-memory--open";
const PANEL_ID = "vcai-memory-panel";
const TOGGLE_ID = "vcai-memory-toggle";
const BACKDROP_ID = "vcai-memory-backdrop";
const MANAGEMENT_KEY = "vcai-memory-management-visible";
const OPEN_KEY = "vcai-memory-panel-open";

function storedBoolean(key, fallback) {
  try {
    const value = localStorage.getItem(key);
    return value === null ? fallback : value === "true";
  } catch {
    return fallback;
  }
}

function storeBoolean(key, value) {
  try {
    localStorage.setItem(key, String(value));
  } catch {
    // Storage can be unavailable in hardened/private browser contexts.
  }
}

function humanizeKey(key) {
  const humanized = String(key || "")
    .replace(/[_-]+/g, " ")
    .replace(/\s+/g, " ")
    .trim();
  return humanized.replace(/(^|\s)\p{L}/gu, (letter) => letter.toUpperCase());
}

export default apiInitializer((api) => {
  if (settings.vcai_enabled !== true || settings.vcai_memory_enabled !== true) {
    return;
  }

  const t = (key, options) => i18n(themePrefix(`vcai_memory.${key}`), options);
  let refreshVersion = 0;
  let mountScheduled = false;

  // One-time, copy-only migration from the legacy right-sidebar component.
  // The old keys are intentionally NOT removed while the legacy component may
  // still be installed during staged rollout; remove them (and this shim) in a
  // later release once the legacy component is retired everywhere.
  (function migrateLegacyPreferences() {
    const migrations = [
      ["vc-ai-memories-enabled", MANAGEMENT_KEY],
      ["vc-ai-panel-open", OPEN_KEY],
    ];
    try {
      for (const [oldKey, newKey] of migrations) {
        if (
          localStorage.getItem(newKey) === null &&
          localStorage.getItem(oldKey) !== null
        ) {
          localStorage.setItem(newKey, localStorage.getItem(oldKey));
        }
      }
    } catch {
      // Storage can be unavailable in hardened/private browser contexts.
    }
  })();

  function autoOpenAllowed() {
    // A remembered "open" preference should not cover the conversation on
    // small screens; manual opening is always available via the caret.
    return window.innerWidth >= 600;
  }

  function enabled() {
    return (
      settings.vcai_enabled === true && settings.vcai_memory_enabled === true
    );
  }

  function eligible() {
    return routeState().eligible;
  }

  function managementVisible() {
    return storedBoolean(MANAGEMENT_KEY, true);
  }

  async function loadMemories() {
    const response = await ajax("/ai-persistent-memory");
    return Array.isArray(response?.memories) ? response.memories : [];
  }

  async function createMemory(key, value) {
    return ajax("/ai-persistent-memory", {
      type: "POST",
      data: { key, value },
    });
  }

  async function removeMemory(key) {
    return ajax(`/ai-persistent-memory/${encodeURIComponent(key)}`, {
      type: "DELETE",
    });
  }

  function messageState(kind, titleText, bodyText) {
    const state = document.createElement("div");
    state.className = `vcai-memory-state vcai-memory-state--${kind}`;

    const title = document.createElement("h3");
    title.className = "vcai-memory-state__title";
    title.textContent = titleText;

    const body = document.createElement("p");
    body.className = "vcai-memory-state__body";
    body.textContent = bodyText;

    state.append(title, body);
    return state;
  }

  function buildAddForm(onSaved) {
    const details = document.createElement("details");
    details.className = "vcai-memory-add";

    const summary = document.createElement("summary");
    summary.className = "vcai-memory-add__summary";
    summary.textContent = t("add_summary");

    const form = document.createElement("form");
    form.className = "vcai-memory-add__form";

    const keyLabel = document.createElement("label");
    keyLabel.className = "vcai-memory-field";
    const keyText = document.createElement("span");
    keyText.textContent = t("add_key_label");
    const keyInput = document.createElement("input");
    keyInput.type = "text";
    keyInput.required = true;
    keyInput.autocomplete = "off";
    keyInput.placeholder = t("add_key_placeholder");
    keyLabel.append(keyText, keyInput);

    const valueLabel = document.createElement("label");
    valueLabel.className = "vcai-memory-field";
    const valueText = document.createElement("span");
    valueText.textContent = t("add_value_label");
    const valueInput = document.createElement("textarea");
    valueInput.required = true;
    valueInput.rows = 3;
    valueInput.placeholder = t("add_value_placeholder");
    valueLabel.append(valueText, valueInput);

    const save = document.createElement("button");
    save.type = "submit";
    save.className = "vcai-memory-add__save";
    save.textContent = t("add_save");

    const error = document.createElement("p");
    error.className = "vcai-memory-add__error";
    error.setAttribute("role", "alert");

    form.append(keyLabel, valueLabel, save, error);
    details.append(summary, form);

    form.addEventListener("submit", async (event) => {
      event.preventDefault();
      const key = keyInput.value.trim();
      const value = valueInput.value.trim();
      if (!key || !value) {
        return;
      }

      save.disabled = true;
      error.textContent = "";
      try {
        await createMemory(key, value);
        form.reset();
        details.open = false;
        await onSaved();
      } catch (requestError) {
        console.error("[vcai-memory] Save failed", requestError);
        error.textContent = t("add_failed");
      } finally {
        save.disabled = false;
      }
    });

    return details;
  }

  function memoryCard(memory, onDeleted) {
    const rawKey = String(memory?.key || "");
    const humanKey = humanizeKey(rawKey) || rawKey;

    const card = document.createElement("article");
    card.className = "vcai-memory-card";

    const heading = document.createElement("h3");
    heading.className = "vcai-memory-card__heading";
    heading.textContent = humanKey;

    const raw = document.createElement("code");
    raw.className = "vcai-memory-card__key";
    raw.textContent = rawKey;

    const value = document.createElement("p");
    value.className = "vcai-memory-card__value";
    value.textContent = String(memory?.value ?? "");

    const remove = document.createElement("button");
    remove.type = "button";
    remove.className = "vcai-memory-card__delete";
    remove.textContent = "×";
    remove.setAttribute("aria-label", `${t("delete_label")}: ${humanKey}`);
    remove.setAttribute("title", t("delete_label"));
    remove.addEventListener("click", async () => {
      if (
        settings.vcai_memory_confirm_delete !== false &&
        !window.confirm(t("delete_confirm"))
      ) {
        return;
      }

      remove.disabled = true;
      try {
        await removeMemory(rawKey);
        card.classList.add("vcai-memory-card--removing");
        setTimeout(onDeleted, 160);
      } catch (error) {
        console.error("[vcai-memory] Delete failed", error);
        window.alert(t("delete_failed"));
        remove.disabled = false;
      }
    });

    card.append(heading);
    if (humanKey.toLocaleLowerCase() !== rawKey.toLocaleLowerCase()) {
      card.appendChild(raw);
    }
    card.append(value, remove);
    return card;
  }

  async function refresh() {
    const panel = document.getElementById(PANEL_ID);
    const content = panel?.querySelector(".vcai-memory-panel__content");
    if (!panel || !content) {
      return;
    }

    const version = ++refreshVersion;
    content.textContent = "";

    if (!managementVisible()) {
      content.appendChild(
        messageState("paused", t("paused_title"), t("paused_body"))
      );
      return;
    }

    const loading = document.createElement("p");
    loading.className = "vcai-memory-loading";
    loading.textContent = t("loading");
    content.appendChild(loading);

    try {
      const memories = await loadMemories();
      if (version !== refreshVersion || !document.getElementById(PANEL_ID)) {
        return;
      }

      content.textContent = "";
      content.appendChild(buildAddForm(refresh));

      if (!memories.length) {
        content.appendChild(
          messageState("empty", t("empty_title"), t("empty_body"))
        );
        return;
      }

      const list = document.createElement("div");
      list.className = "vcai-memory-list";
      memories.forEach((memory) => {
        list.appendChild(memoryCard(memory, refresh));
      });
      content.appendChild(list);
    } catch (error) {
      if (version !== refreshVersion) {
        return;
      }
      console.warn("[vcai-memory] Load failed", error);
      content.textContent = "";
      content.appendChild(
        messageState(
          "unavailable",
          t("unavailable_title"),
          t("unavailable_body")
        )
      );
    }
  }

  function setOpen(open, remember = true) {
    const wasOpen = document.body.classList.contains(OPEN_CLASS);
    if (open) {
      window.dispatchEvent(
        new CustomEvent("vcai:drawer-opening", {
          detail: { owner: "memory" },
        })
      );
    }
    document.body.classList.toggle(OPEN_CLASS, open);
    const toggle = document.getElementById(TOGGLE_ID);
    toggle?.setAttribute("aria-expanded", String(open));
    toggle?.setAttribute("aria-label", open ? t("close_panel") : t("open_panel"));
    if (remember) {
      storeBoolean(OPEN_KEY, open);
    }
    // Load lazily and re-load on every open so memories the AI saved during
    // the conversation are visible without a manual toggle.
    if (open && (!wasOpen || !panelHasContent())) {
      refresh();
    }
  }

  function panelHasContent() {
    return Boolean(
      document
        .getElementById(PANEL_ID)
        ?.querySelector(".vcai-memory-panel__content")?.childElementCount
    );
  }

  function buildPanel() {
    const panel = document.createElement("aside");
    panel.id = PANEL_ID;
    panel.className = "vcai-memory-panel";
    panel.setAttribute("aria-labelledby", "vcai-memory-title");

    const header = document.createElement("header");
    header.className = "vcai-memory-panel__header";

    const titleWrap = document.createElement("div");
    titleWrap.className = "vcai-memory-panel__title-wrap";
    const eyebrow = document.createElement("span");
    eyebrow.className = "vcai-memory-panel__eyebrow";
    eyebrow.textContent = t("eyebrow");
    const title = document.createElement("h2");
    title.id = "vcai-memory-title";
    title.className = "vcai-memory-panel__title";
    title.textContent = t("title");
    titleWrap.append(eyebrow, title);

    const managementLabel = document.createElement("label");
    managementLabel.className = "vcai-memory-switch";
    managementLabel.setAttribute("title", t("management_toggle"));
    const management = document.createElement("input");
    management.type = "checkbox";
    management.checked = managementVisible();
    management.setAttribute("aria-label", t("management_toggle"));
    const slider = document.createElement("span");
    slider.className = "vcai-memory-switch__slider";
    managementLabel.append(management, slider);

    const content = document.createElement("div");
    content.className = "vcai-memory-panel__content";

    management.addEventListener("change", () => {
      storeBoolean(MANAGEMENT_KEY, management.checked);
      refresh();
    });

    header.append(titleWrap, managementLabel);
    panel.append(header, content);
    return panel;
  }

  function buildToggle() {
    const toggle = document.createElement("button");
    toggle.id = TOGGLE_ID;
    toggle.className = "vcai-memory-toggle";
    toggle.type = "button";
    toggle.innerHTML = '<span aria-hidden="true">›</span>';
    toggle.setAttribute("aria-controls", PANEL_ID);
    toggle.setAttribute("aria-label", t("toggle_panel"));
    toggle.addEventListener("click", () => {
      setOpen(!document.body.classList.contains(OPEN_CLASS));
    });
    return toggle;
  }

  function removeInjected() {
    refreshVersion += 1;
    document.getElementById(PANEL_ID)?.remove();
    document.getElementById(TOGGLE_ID)?.remove();
    document.getElementById(BACKDROP_ID)?.remove();
    // toggle(name, false) is a no-op when the class is absent. remove()
    // rewrites the class attribute even then, which fires bodyObserver
    // below and re-runs mount() every frame, forever.
    document.body.classList.toggle(ROOT_CLASS, false);
    document.body.classList.toggle(OPEN_CLASS, false);
    document.body.style.removeProperty("--vcai-memory-width");
  }

  function mount() {
    if (!enabled() || !eligible()) {
      removeInjected();
      return;
    }

    // Same reason as removeInjected: add() would rewrite the attribute
    // even when the class is already there.
    document.body.classList.toggle(ROOT_CLASS, true);
    document.body.style.setProperty(
      "--vcai-memory-width",
      `${Number(settings.vcai_memory_width) || 400}px`
    );

    if (!document.getElementById(PANEL_ID)) {
      document.body.appendChild(buildPanel());
      document.body.appendChild(buildToggle());

      const backdrop = document.createElement("button");
      backdrop.id = BACKDROP_ID;
      backdrop.className = "vcai-memory-backdrop";
      backdrop.type = "button";
      backdrop.setAttribute("aria-label", t("close_panel"));
      backdrop.addEventListener("click", () => setOpen(false));
      document.body.appendChild(backdrop);

      const wantOpen = storedBoolean(
        OPEN_KEY,
        settings.vcai_memory_default_open === true
      );
      setOpen(wantOpen && autoOpenAllowed(), false);
    }
  }

  function scheduleMount() {
    if (mountScheduled) {
      return;
    }
    mountScheduled = true;
    nextPaint(() => {
      mountScheduled = false;
      mount();
    });
  }

  ensureRouteState(api);
  onRouteState(() => {
    scheduleMount();
    if (
      eligible() &&
      document.getElementById(PANEL_ID) &&
      document.body.classList.contains(OPEN_CLASS)
    ) {
      refresh();
    }
  });

  // The header Memories control (header-controls module) drives the panel
  // through this event; this module stays the single owner of panel state.
  window.addEventListener("vcai:memory:toggle", () => {
    if (enabled() && eligible()) {
      setOpen(!document.body.classList.contains(OPEN_CLASS));
    }
  });

  document.addEventListener("keydown", (event) => {
    if (event.key === "Escape" && document.body.classList.contains(OPEN_CLASS)) {
      setOpen(false);
    }
  });
  window.addEventListener("vcai:drawer-opening", (event) => {
    if (event.detail?.owner !== "memory") {
      setOpen(false, false);
    }
  });

  const bodyObserver = new MutationObserver(scheduleMount);
  bodyObserver.observe(document.body, {
    attributes: true,
    attributeFilter: ["class"],
  });
  mount();
});
