import { apiInitializer } from "discourse/lib/api";
import classPrepend from "discourse/lib/class-prepend";
import DropdownSelectBox from "discourse/select-kit/components/dropdown-select-box";
import { i18n } from "discourse-i18n";

// Keep native options, validation and change callbacks. Only mobile presentation
// changes; no agent IDs, recipient logic or permission rules are reconstructed.
export default apiInitializer((api) => {
  const mobile = window.matchMedia("(max-width: 767px)");
  const sheets = new WeakMap();
  let activeClose;
  const t = (key) => i18n(themePrefix(`vcai_composer.${key}`));
  const eligible = (component) => settings.vcai_enabled === true &&
    settings.vcai_workspace_enabled === true && mobile.matches &&
    document.body.classList.contains("vcai-workspace--landing") &&
    component.element?.closest(".agent-llm-selector") &&
    typeof HTMLDialogElement !== "undefined";

  function openSheet(component) {
    if (sheets.has(component)) { return; }
    activeClose?.();
    const header = component.getHeader();
    const dialog = document.createElement("dialog");
    dialog.className = "vcai-selector-dialog";
    dialog.setAttribute("aria-label", t(component.element.classList.contains(
      "agent-llm-selector__llm-dropdown") ? "choose_model" : "choose_agent"));
    const panel = document.createElement("section");
    panel.className = "vcai-selector-sheet";
    const heading = document.createElement("div");
    heading.className = "vcai-selector-sheet__heading";
    const title = document.createElement("h2");
    title.textContent = dialog.getAttribute("aria-label");
    const close = document.createElement("button");
    close.type = "button";
    close.className = "btn btn-flat";
    close.textContent = t("close_picker");
    heading.append(title, close);
    const search = document.createElement("input");
    search.type = "search";
    search.placeholder = t("search_choices");
    search.setAttribute("aria-label", t("search_choices"));
    const list = document.createElement("div");
    list.className = "vcai-selector-sheet__choices";
    const error = document.createElement("p");
    error.setAttribute("role", "alert");
    error.hidden = true;
    panel.append(heading, search, list, error);
    dialog.append(panel);
    let closed = false;
    let choosing = false;
    const viewport = window.visualViewport;
    const layout = () => {
      dialog.style.setProperty("--vcai-picker-height", `${viewport?.height || window.innerHeight}px`);
      dialog.style.setProperty("--vcai-picker-top", `${viewport?.offsetTop || 0}px`);
    };
    const dismiss = () => {
      if (closed) { return; }
      closed = true;
      viewport?.removeEventListener("resize", layout);
      viewport?.removeEventListener("scroll", layout);
      mobile.removeEventListener("change", onBreakpoint);
      sheets.delete(component);
      if (activeClose === dismiss) { activeClose = null; }
      dialog.close();
      dialog.remove();
      document.body.classList.remove("vcai-picker-open");
      // Restore after the closing click has finished bubbling through Discourse.
      requestAnimationFrame(() => {
        if (header?.isConnected && !activeClose) { header.focus({ preventScroll: true }); }
      });
    };
    const onBreakpoint = () => { if (!mobile.matches) { dismiss(); } };
    const optionsNow = () => Array.from(component.selectKit.modifyContent(
      Array.from(component.content || [])) || []).filter(Boolean);
    const plainText = (value) => {
      const template = document.createElement("template");
      template.innerHTML = String(value || "");
      template.content.querySelectorAll("script, style").forEach((node) => node.remove());
      return template.content.textContent || "";
    };
    const render = () => {
      list.replaceChildren();
      const query = search.value.trim().toLocaleLowerCase();
      // Re-read the native content on every search/selection, not a copied catalog.
      const options = optionsNow();
      for (const item of options) {
        const name = plainText(component.getName(item));
        const description = plainText(item.description);
        if (query && !`${name} ${description}`.toLocaleLowerCase().includes(query)) { continue; }
        const button = document.createElement("button");
        button.type = "button";
        button.className = "vcai-selector-sheet__choice";
        const selected = component.getValue(item) === component.value;
        button.setAttribute("aria-pressed", String(selected));
        const label = document.createElement("strong");
        label.textContent = name;
        button.append(label);
        if (selected) {
          const current = document.createElement("span");
          current.className = "vcai-selector-sheet__current";
          current.textContent = t("current_choice");
          button.append(current);
        }
        if (description) {
          const detail = document.createElement("span");
          detail.className = "vcai-selector-sheet__description";
          detail.textContent = description;
          button.append(detail);
        }
        button.addEventListener("click", async () => {
          if (choosing || component.isDestroying || component.isDestroyed) { return; }
          const currentItem = optionsNow().find(
            (entry) => component.getValue(entry) === component.getValue(item));
          if (!currentItem || !component.validateSelect(currentItem)) { render(); return; }
          choosing = true;
          try {
            await component.selectKit.change(component.getValue(currentItem), currentItem);
            dismiss();
          } catch {
            error.textContent = t("selection_failed");
            error.hidden = false;
          } finally { choosing = false; }
        });
        list.append(button);
      }
      if (!list.childElementCount) {
        const empty = document.createElement("p");
        empty.textContent = t("no_choices");
        list.append(empty);
      }
    };
    close.addEventListener("click", dismiss);
    dialog.addEventListener("cancel", (event) => { event.preventDefault(); dismiss(); });
    search.addEventListener("input", render);
    sheets.set(component, dismiss);
    activeClose = dismiss;
    // Never open the floating select-kit popup. An opening tap cannot also hit
    // an outside-dismiss handler: dismissal is explicit Close, Escape or choice.
    component.element.open = false;
    document.body.append(dialog);
    document.body.classList.add("vcai-picker-open");
    layout();
    render();
    dialog.showModal();
    close.focus({ preventScroll: true });
    viewport?.addEventListener("resize", layout);
    viewport?.addEventListener("scroll", layout);
    mobile.addEventListener("change", onBreakpoint);
  }

  classPrepend(DropdownSelectBox, (Superclass) => class extends Superclass {
    _open(event) {
      if (eligible(this) && !this.selectKit.isDisabled && !this.selectKit.options.disabled) {
        event?.preventDefault();
        event?.stopPropagation();
        openSheet(this);
        return;
      }
      return super._open(...arguments);
    }
    willDestroyElement() {
      sheets.get(this)?.();
      return super.willDestroyElement(...arguments);
    }
  });
  api.onPageChange(() => activeClose?.());
});
