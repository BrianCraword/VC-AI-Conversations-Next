import { apiInitializer } from "discourse/lib/api";
import { getUploadMarkdown } from "discourse/lib/uploads";
import { i18n } from "discourse-i18n";
import { draftLengthState, draftPayload } from "../lib/vcai-draft-length";
import { ensureRouteState, nextPaint, onRouteState } from "../lib/vcai-route-state";

const NOTE_ID = "vcai-draft-length";

export default apiInitializer((api) => {
  const enabled = () => settings.vcai_enabled === true && settings.vcai_workspace_enabled === true;
  if (!enabled()) { return; }
  const siteSettings = api.container.lookup("service:site-settings");
  const t = (key, values) => i18n(themePrefix(`vcai_composer.${key}`), values);

  function updateFeedback() {
    const input = document.querySelector("body.vcai-workspace--landing #ai-bot-conversations-input");
    if (!input || !enabled()) { return; }
    const container = input.closest(".ai-bot-conversations__input-container");
    if (!container) { return; }
    let note = document.getElementById(NOTE_ID);
    if (!note) {
      note = document.createElement("p");
      note.id = NOTE_ID;
      note.className = "vcai-draft-length";
      note.setAttribute("role", "status");
      note.setAttribute("aria-live", "polite");
      container.appendChild(note);
    }
    const state = draftLengthState(input.value, siteSettings.max_post_length);
    note.hidden = !state.near;
    const text = state.near ? t(state.over ? "over_limit" : "near_limit", state) : "";
    if (note.textContent !== text) { note.textContent = text; }
    note.classList.toggle("is-over", state.over);
    const describedBy = new Set((input.getAttribute("aria-describedby") || "").split(/\s+/).filter(Boolean));
    describedBy.add(NOTE_ID);
    input.setAttribute("aria-describedby", [...describedBy].join(" "));
    if (state.over) {
      input.setAttribute("aria-invalid", "true");
      input.dataset.vcaiOverlength = "true";
    } else if (input.dataset.vcaiOverlength) {
      input.removeAttribute("aria-invalid");
      delete input.dataset.vcaiOverlength;
    }
  }

  // Guard the native service, covering Ask, keyboard shortcuts and outlet callers.
  // Reject rather than resolve early: the native caller clears uploads on resolve.
  api.modifyClass("service:ai-bot-conversations-hidden-submit", (Superclass) =>
    class extends Superclass {
      async submitToBot(uploadData) {
        if (enabled()) {
          const raw = draftPayload(this.inputValue,
            (uploadData?.uploads || []).map((upload) => getUploadMarkdown(upload)));
          const state = draftLengthState(raw, this.siteSettings.max_post_length);
          if (state.over) {
            updateFeedback();
            throw { responseJSON: { error: t("send_too_long", state) } };
          }
        }
        return super.submitToBot(...arguments);
      }
    }
  );

  document.addEventListener("input", (event) => {
    if (event.target.id === "ai-bot-conversations-input") { updateFeedback(); }
  });
  ensureRouteState(api);
  onRouteState(() => nextPaint(updateFeedback));
  const observer = new MutationObserver((mutations) => {
    if (mutations.some((mutation) => [...mutation.addedNodes].some((node) =>
      node.nodeType === Node.ELEMENT_NODE &&
      (node.id === "ai-bot-conversations-input" || node.querySelector?.("#ai-bot-conversations-input"))
    ))) { nextPaint(updateFeedback); }
  });
  observer.observe(document.body, { childList: true, subtree: true });
  nextPaint(updateFeedback);
});
