import { apiInitializer } from "discourse/lib/api";
import { i18n } from "discourse-i18n";

// No core imports, class patches, copied choices or selection callbacks.
// Portal the existing native details control only after an explicit activation.
export default apiInitializer((api) => {
  const mobile = window.matchMedia("(max-width: 767px)");
  let active;
  const enabled = () => settings.vcai_enabled === true && settings.vcai_workspace_enabled === true;
  const t = (key) => i18n(themePrefix(`vcai_composer.${key}`));
  function open(header, picker) {
    if (active) { return; }
    const marker = document.createComment("vcai-native-picker-position");
    picker.before(marker);
    const dialog = document.createElement("dialog");
    dialog.className = "vcai-native-picker-dialog";
    dialog.setAttribute("aria-label", t(picker.classList.contains("agent-llm-selector__llm-dropdown") ? "choose_model" : "choose_agent"));
    const heading = document.createElement("div");
    heading.className = "vcai-native-picker-heading";
    const title = document.createElement("h2");
    title.textContent = dialog.getAttribute("aria-label");
    const close = document.createElement("button");
    close.type = "button";
    close.className = "btn btn-flat";
    close.textContent = t("close_picker");
    heading.append(title, close);
    dialog.append(heading, picker);
    document.body.append(dialog);
    const viewport = window.visualViewport;
    const layout = () => {
      const height = viewport?.height || window.innerHeight;
      dialog.style.setProperty("--vcai-picker-height", `${height}px`);
      dialog.style.top = `${viewport?.offsetTop || 0}px`;
    };
    let done = false;
    const finish = () => {
      if (done) { return; }
      done = true;
      observer.disconnect();
      viewport?.removeEventListener("resize", layout);
      viewport?.removeEventListener("scroll", layout);
      mobile.removeEventListener("change", breakpoint);
      picker.open = false;
      if (marker.isConnected) { marker.replaceWith(picker); }
      dialog.close();
      dialog.remove();
      document.body.classList.remove("vcai-native-picker-open");
      active = null;
      requestAnimationFrame(() => {
        if (header.isConnected && !active) { header.focus({ preventScroll: true }); }
      });
    };
    const observer = new MutationObserver(() => {
      if (!picker.open || !marker.isConnected || !enabled()) { finish(); }
    });
    const breakpoint = () => { if (!mobile.matches) { finish(); } };
    active = finish;
    close.addEventListener("click", finish);
    dialog.addEventListener("cancel", (event) => { event.preventDefault(); finish(); });
    // Keep native Tab-dismiss from treating the modal Close button as outside.
    // Default Tab movement remains owned by the browser modal focus trap.
    dialog.addEventListener("keydown", (event) => {
      if (event.key === "Tab") { event.stopPropagation(); }
    }, true);
    layout();
    document.body.classList.add("vcai-native-picker-open");
    dialog.showModal();
    // Native details toggle opens SelectKit through its existing handler.
    // The original touch/click is consumed before document outside-click logic.
    picker.open = true;
    observer.observe(picker, { attributes: true, attributeFilter: ["open"] });
    observer.observe(document.body, { childList: true, subtree: true });
    viewport?.addEventListener("resize", layout);
    viewport?.addEventListener("scroll", layout);
    mobile.addEventListener("change", breakpoint);
    close.focus({ preventScroll: true });
  }
  function activate(event) {
    if (!enabled() || !mobile.matches || !document.body.classList.contains("vcai-workspace--landing")) { return; }
    const header = event.target.closest?.(".agent-llm-selector .select-kit-header");
    const picker = header?.closest("details.select-kit");
    if (!picker || picker.classList.contains("is-disabled") || header.getAttribute("aria-disabled") === "true" ||
      typeof HTMLDialogElement === "undefined") { return; }
    if (event.type === "keydown" && !["Enter", " ", "ArrowDown", "ArrowUp"].includes(event.key)) { return; }
    event.preventDefault();
    event.stopImmediatePropagation();
    open(header, picker);
  }
  document.addEventListener("click", activate, true);
  document.addEventListener("keydown", activate, true);
  api.onPageChange(() => active?.());
});
