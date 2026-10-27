import { apiInitializer } from "discourse/lib/api";
import { i18n } from "discourse-i18n";
import {
  ensureRouteState,
  nextPaint,
  onRouteState,
  routeState,
} from "../lib/vcai-route-state";

const ROOT_CLASS = "vcai-workspace";
const LANDING_CLASS = "vcai-workspace--landing";
const THREAD_CLASS = "vcai-workspace--thread";
const AMBIENT_CLASS = "vcai-ambient";
const AGENT_DOCKED_CLASS = "vcai-agent-docked";
const MARK_ID = "vcai-greeting-mark";
const STARTERS_ID = "vcai-starters";
const CHIP_ID = "vcai-status-chip";
const SUBTITLE_ID = "vcai-subtitle";
const GREETING_SESSION_KEY = "vcai-greeting-index";

function listSetting(value) {
  return String(value || "")
    .split("|")
    .map((entry) => entry.trim())
    .filter(Boolean);
}

function starterEntries(value) {
  return listSetting(value)
    .map((entry) => {
      const separator = entry.indexOf("::");
      if (separator < 1) {
        return null;
      }
      const label = entry.slice(0, separator).trim();
      const prompt = entry.slice(separator + 2).trim();
      return label && prompt ? { label, prompt } : null;
    })
    .filter(Boolean);
}

function setTextareaValue(textarea, value) {
  const setter = Object.getOwnPropertyDescriptor(
    window.HTMLTextAreaElement.prototype,
    "value"
  )?.set;

  if (setter) {
    setter.call(textarea, value);
  } else {
    textarea.value = value;
  }

  textarea.dispatchEvent(new Event("input", { bubbles: true }));
  textarea.dispatchEvent(new Event("change", { bubbles: true }));
  textarea.focus();
  textarea.setSelectionRange(value.length, value.length);
}

export default apiInitializer((api) => {
  if (settings.vcai_enabled !== true || settings.vcai_workspace_enabled !== true) {
    return;
  }

  const t = (key, options) => i18n(themePrefix(`vcai_workspace.${key}`), options);
  let mountScheduled = false;

  function enabled() {
    return (
      settings.vcai_enabled === true && settings.vcai_workspace_enabled === true
    );
  }

  // Route eligibility comes from the shared core (lib/vcai-route-state), not
  // from a local read of body classes at a guessed moment.
  function eligibleState() {
    return routeState();
  }

  function removeLandingEnhancements() {
    document.getElementById(MARK_ID)?.remove();
    document.getElementById(STARTERS_ID)?.remove();
    document.getElementById(CHIP_ID)?.remove();
    document.getElementById(SUBTITLE_ID)?.remove();
    document.body.classList.remove(AGENT_DOCKED_CLASS, AMBIENT_CLASS);
  }

  function clearState() {
    document.body.classList.remove(ROOT_CLASS, LANDING_CLASS, THREAD_CLASS);
    removeLandingEnhancements();
  }

  function memberFirstName() {
    const user = api.getCurrentUser?.();
    const raw = user?.name || user?.username || "Friend";
    return String(raw).trim().split(/\s+/)[0] || "Friend";
  }

  function greetingText() {
    const greetings = listSetting(settings.vcai_workspace_greeting_phrases);
    const pool = greetings.length
      ? greetings
      : ["What shall we discover today?"];
    let stored = Number.NaN;
    try {
      // Copy-only migration from the legacy greeting component's key so a
      // mid-session switchover keeps the same greeting.
      if (sessionStorage.getItem(GREETING_SESSION_KEY) === null) {
        const legacy = sessionStorage.getItem("vc-ai-greeting-index");
        if (legacy !== null) {
          sessionStorage.setItem(GREETING_SESSION_KEY, legacy);
        }
      }
      stored = Number.parseInt(sessionStorage.getItem(GREETING_SESSION_KEY), 10);
    } catch {
      // A hardened browser can deny session storage; random selection still works.
    }
    const index = Number.isInteger(stored) && stored >= 0 && stored < pool.length
      ? stored
      : Math.floor(Math.random() * pool.length);

    try {
      sessionStorage.setItem(GREETING_SESSION_KEY, String(index));
    } catch {
      // Keep the greeting functional even when browser storage is unavailable.
    }
    return pool[index].replace(/\{name\}/g, memberFirstName());
  }

  function contentWrapper() {
    return document.querySelector(".ai-bot-conversations__content-wrapper");
  }

  function mountGreeting() {
    const title = document.querySelector(".ai-bot-conversations__title");
    if (!title) {
      return;
    }

    title.textContent = greetingText();

    if (document.getElementById(MARK_ID)) {
      return;
    }

    const mark = document.createElement("div");
    mark.id = MARK_ID;
    mark.className = "vcai-greeting-mark";

    const image = document.createElement("img");
    image.className = "vcai-greeting-mark__image";
    image.src = settings.vcai_workspace_greeting_image_url || "/custom-images/Fire.svg";
    image.alt = "";
    image.setAttribute("aria-hidden", "true");
    mark.appendChild(image);

    title.parentElement?.insertBefore(mark, title);
  }

  // The agent name is rendered by Discourse inside the select-kit header, so it
  // is read from the DOM rather than duplicated from a setting.
  function activeAgentName() {
    const node = document.querySelector(
      ".agent-llm-selector .select-kit-header .name"
    );
    return node?.textContent?.trim() || "";
  }

  function mountStatusChip() {
    if (settings.vcai_workspace_status_chip_enabled === false) {
      document.getElementById(CHIP_ID)?.remove();
      return;
    }

    const title = document.querySelector(".ai-bot-conversations__title");
    if (!title) {
      return;
    }

    let chip = document.getElementById(CHIP_ID);
    if (!chip) {
      chip = document.createElement("div");
      chip.id = CHIP_ID;
      chip.className = "vcai-status-chip";

      const dot = document.createElement("span");
      dot.className = "vcai-status-chip__dot";

      const label = document.createElement("span");
      label.className = "vcai-status-chip__label";

      const rule = document.createElement("span");
      rule.className = "vcai-status-chip__rule";

      const agent = document.createElement("span");
      agent.className = "vcai-status-chip__agent";

      chip.append(dot, label, rule, agent);

      const mark = document.getElementById(MARK_ID);
      const reference = mark && mark.parentElement === title.parentElement ? mark : title;
      title.parentElement?.insertBefore(chip, reference);
    }

    chip.querySelector(".vcai-status-chip__label").textContent =
      settings.vcai_workspace_status_chip_label || t("status_ready");

    const agentName = activeAgentName();
    chip.querySelector(".vcai-status-chip__agent").textContent = agentName;
    chip.querySelector(".vcai-status-chip__rule").hidden = !agentName;
  }

  function mountSubtitle() {
    const text = String(settings.vcai_workspace_subtitle || "").trim();
    const title = document.querySelector(".ai-bot-conversations__title");

    if (!text || !title) {
      document.getElementById(SUBTITLE_ID)?.remove();
      return;
    }

    let subtitle = document.getElementById(SUBTITLE_ID);
    if (!subtitle) {
      subtitle = document.createElement("p");
      subtitle.id = SUBTITLE_ID;
      subtitle.className = "vcai-subtitle";
      title.insertAdjacentElement("afterend", subtitle);
    }
    subtitle.textContent = text;
  }

  // Discourse renders the agent selector as a sibling of the composer card.
  // Moving it inside the card lets upload / agent / send share one footer row;
  // the move is idempotent and re-applied after any Discourse re-render.
  function dockAgentSelector() {
    const wrapper = document.querySelector(
      ".ai-bot-conversations__input-wrapper"
    );
    const selector = document.querySelector(".agent-llm-selector");

    if (settings.vcai_workspace_dock_agent_selector === false || !wrapper || !selector) {
      document.body.classList.remove(AGENT_DOCKED_CLASS);
      return;
    }

    if (selector.parentElement !== wrapper) {
      wrapper.appendChild(selector);
    }
    document.body.classList.add(AGENT_DOCKED_CLASS);
  }

  function decorateSubmit() {
    const submit = document.querySelector(".ai-conversation-submit");
    if (!submit) {
      return;
    }

    const existing = submit.querySelector(".vcai-submit-label");

    if (settings.vcai_workspace_submit_label_enabled === false) {
      existing?.remove();
      submit.querySelector(".vcai-submit-hint")?.remove();
      return;
    }

    if (existing) {
      return;
    }

    const label = document.createElement("span");
    label.className = "vcai-submit-label";
    label.textContent = t("submit_label");

    const hint = document.createElement("span");
    hint.className = "vcai-submit-hint";
    hint.setAttribute("aria-hidden", "true");
    hint.textContent = t("submit_hint");

    submit.append(label, hint);
  }

  function startersSignature() {
    return [
      settings.vcai_workspace_starter_count,
      settings.vcai_workspace_starter_prompts,
    ].join("\u0001");
  }

  function mountStarters() {
    if (settings.vcai_workspace_starters_enabled === false) {
      document.getElementById(STARTERS_ID)?.remove();
      return;
    }

    // applyState() re-runs on page-change retries and observed mutations.
    // Rebuilding the buttons each time flickers and drops keyboard focus, so
    // an existing region is kept unless its settings signature changed.
    const signature = startersSignature();
    const existing = document.getElementById(STARTERS_ID);
    if (existing?.dataset.vcaiSignature === signature) {
      return;
    }
    existing?.remove();

    const content = contentWrapper();
    if (!content) {
      return;
    }

    const count = Math.max(
      0,
      Math.min(Number(settings.vcai_workspace_starter_count) || 0, 8)
    );
    const entries = starterEntries(settings.vcai_workspace_starter_prompts).slice(0, count);

    if (!entries.length) {
      return;
    }

    const region = document.createElement("div");
    region.id = STARTERS_ID;
    region.className = "vcai-starters";
    region.dataset.vcaiSignature = signature;
    region.setAttribute("aria-label", t("starters_label"));

    entries.forEach(({ label, prompt }) => {
      const button = document.createElement("button");
      button.type = "button";
      button.className = "vcai-starter";
      // Known labels get meaningful decorative icons; customized labels keep a
      // neutral compass. Labels, prompts and click behavior remain configured.
      const icons = {
        "Open a passage": "book-open",
        "Trace a doctrine": "seedling",
        "Test a teaching": "scale-balanced",
        "Explore context": "magnifying-glass",
        "Apply the text": "leaf",
        "Surprise me": "lightbulb",
      };
      const icon = document.createElementNS("http://www.w3.org/2000/svg", "svg");
      icon.classList.add("d-icon", "vcai-starter-icon");
      icon.setAttribute("aria-hidden", "true");
      icon.setAttribute("focusable", "false");
      const use = document.createElementNS("http://www.w3.org/2000/svg", "use");
      use.setAttribute("href", `#${Object.hasOwn(icons, label) ? icons[label] : "compass"}`);
      icon.appendChild(use);
      button.append(icon, document.createTextNode(label));
      button.addEventListener("click", () => {
        // Resolved at click time: Discourse may re-render the composer after
        // this region is built, which would leave a captured node stale.
        const textarea = document.querySelector("#ai-bot-conversations-input");
        if (textarea) {
          setTextareaValue(textarea, prompt);
        }
      });
      region.appendChild(button);
    });

    // Visual order is owned by CSS `order`, so appending is enough — the
    // starters render below the composer without depending on sibling nodes.
    content.appendChild(region);
  }

  function applyState() {
    if (!enabled()) {
      clearState();
      return;
    }

    const state = eligibleState();
    if (!state.eligible) {
      clearState();
      return;
    }

    document.body.classList.add(ROOT_CLASS);
    document.body.classList.toggle(LANDING_CLASS, state.landing);
    document.body.classList.toggle(THREAD_CLASS, state.thread);

    if (state.landing) {
      document.body.classList.toggle(
        AMBIENT_CLASS,
        settings.vcai_workspace_ambient_field_enabled !== false
      );
      mountGreeting();
      mountStatusChip();
      mountSubtitle();
      mountStarters();
      dockAgentSelector();
      decorateSubmit();
    } else {
      removeLandingEnhancements();
    }
  }

  function scheduleApply() {
    if (mountScheduled) {
      return;
    }
    mountScheduled = true;
    nextPaint(() => {
      mountScheduled = false;
      applyState();
    });
  }

  // The shared route-state core publishes on every page change and on every
  // change of the Discourse AI route classes, however late they land. One
  // short follow-up covers the title/composer nodes that render just after
  // the class flips; the mutation observer below covers anything later.
  ensureRouteState(api);
  onRouteState(() => {
    scheduleApply();
    setTimeout(scheduleApply, 120);
  });

  const observer = new MutationObserver((mutations) => {
    if (!enabled() || !eligibleState().eligible) {
      return;
    }
    for (const mutation of mutations) {
      // The status chip mirrors the agent name, so a text change inside the
      // select-kit header has to re-run mounting as well as node additions.
      if (
        mutation.type === "characterData" &&
        mutation.target.parentElement?.closest?.(".agent-llm-selector")
      ) {
        scheduleApply();
        return;
      }
      for (const node of mutation.addedNodes) {
        if (node.nodeType !== Node.ELEMENT_NODE) {
          continue;
        }
        if (
          node.matches?.(".ai-bot-conversations, .ai-bot-conversations__title") ||
          node.querySelector?.(".ai-bot-conversations__title") ||
          node.matches?.(".agent-llm-selector, .ai-bot-conversations__input-wrapper") ||
          node.querySelector?.(".agent-llm-selector") ||
          node.matches?.(".docked-composer") ||
          node.querySelector?.(".docked-composer")
        ) {
          scheduleApply();
          return;
        }
      }
    }
  });

  observer.observe(document.body, {
    childList: true,
    subtree: true,
    characterData: true,
  });
  scheduleApply();
});
