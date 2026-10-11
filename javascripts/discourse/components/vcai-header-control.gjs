import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { registerDestructor } from "@ember/destroyable";
import { action } from "@ember/object";
import DButton from "discourse/components/d-button";
import { i18n } from "discourse-i18n";
import { onRouteState } from "../lib/vcai-route-state";

// VC AI Conversations Next — header control (base)
//
// One icon in Discourse's own header row, rendered through the headerIcons
// API so it inherits the exact size, spacing, and hover treatment of search,
// chat, and the avatar. It owns no state: visibility and open/closed are
// read from the body classes the history and memory modules maintain, and a
// tap dispatches an event those modules answer. Disabling either module
// simply removes its icon.
//
// Subclasses supply: kind, icon, translation keys, visibility rule.

export default class VcaiHeaderControl extends Component {
  @tracked visible = false;
  @tracked open = false;

  kind = "control";
  icon = "circle";
  labelKey = "";
  openKey = "";
  closeKey = "";
  controls = "";

  constructor() {
    super(...arguments);
    this.sync();

    const unsubscribe = onRouteState(() => this.sync());
    this.observer = new MutationObserver(() => this.sync());
    this.observer.observe(document.body, {
      attributes: true,
      attributeFilter: ["class"],
    });

    registerDestructor(this, () => {
      unsubscribe();
      this.observer?.disconnect();
      this.observer = null;
    });
  }

  // Subclasses override: return { visible, open } from body classes.
  readState() {
    return { visible: false, open: false };
  }

  sync() {
    const next = this.readState();
    if (next.visible !== this.visible) {
      this.visible = next.visible;
    }
    if (next.open !== this.open) {
      this.open = next.open;
    }
  }

  get title() {
    return i18n(themePrefix(this.open ? this.closeKey : this.openKey));
  }

  get label() {
    return i18n(themePrefix(this.labelKey));
  }

  @action
  toggle() {
    window.dispatchEvent(new CustomEvent(`vcai:${this.kind}:toggle`));
  }

  <template>
    {{#if this.visible}}
      <li
        class="header-dropdown-toggle vcai-header-control vcai-header-control--{{this.kind}} {{if this.open 'vcai-header-control--open'}}"
      >
        <DButton
          @icon={{this.icon}}
          @action={{this.toggle}}
          @translatedTitle={{this.title}}
          @translatedAriaLabel={{this.title}}
          aria-expanded={{if this.open "true" "false"}}
          aria-controls={{this.controls}}
          class="btn-flat icon no-text vcai-header-control__button"
        />
      </li>
    {{/if}}
  </template>
}
