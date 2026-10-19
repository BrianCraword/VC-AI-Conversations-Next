import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { getOwner } from "@ember/owner";
import { service } from "@ember/service";
import { registerDestructor } from "@ember/destroyable";
import { on } from "@ember/modifier";
import DButton from "discourse/components/d-button";
import { i18n } from "discourse-i18n";
import { routeState, onRouteState } from "../lib/vcai-route-state";
import { eligibleNavigation, hasDraftContent } from "../lib/vcai-navigation-policy";

const HOME = "/discourse-ai/ai-bot/conversations";
export default class VcaiConversationNavigation extends Component {
  @service currentUser;
  @service router;
  @service appEvents;
  @service dialog;
  @service capabilities;
  @tracked state = routeState();
  @tracked path = "";
  @tracked rows = [];
  @tracked busy = false;

  constructor() {
    super(...arguments);
    this.sync();
    const unsubscribe = onRouteState(() => this.sync());
    this.changed = () => this.sync();
    this.router.on("routeDidChange", this.changed);
    registerDestructor(this, () => {
      unsubscribe();
      this.router.off("routeDidChange", this.changed);
    });
  }
  sync() {
    this.state = routeState();
    this.path = this.router.currentURL || "";
    this.rows = [];
    this.menuElement?.removeAttribute("open");
  }
  get visible() {
    return eligibleNavigation({user: this.currentUser, state: this.state, path: this.path,
      topic: getOwner(this).lookup("controller:topic")?.model,
      excludedIds: settings.vcai_navigation_excluded_bot_ids});
  }
  get conversationsLabel() { return i18n(themePrefix("vcai_navigation.conversations")); }
  get newLabel() { return i18n(themePrefix("vcai_navigation.new_conversation")); }
  get menuLabel() { return i18n(themePrefix("vcai_navigation.site_menu")); }
  get feedLabel() { return i18n(themePrefix("vcai_navigation.feed")); }
  canLeave() {
    // Do not clear, serialize or discard draft text. Finish/save it in the native composer first.
    const composer = getOwner(this).lookup("service:composer");
    if (hasDraftContent(document) || String(composer?.model?.reply || "").trim()) {
      this.dialog.alert(i18n(themePrefix("vcai_navigation.draft_notice")));
      return false;
    }
    return true;
  }
  async navigate(href, fresh = false) {
    if (this.busy || !this.canLeave()) { return; }
    this.busy = true;
    try {
      if (fresh) { this.appEvents.trigger("discourse-ai:new-conversation-btn-clicked"); }
      if (this.path.split("?")[0] !== href) { await this.router.transitionTo(href); }
      if (href === HOME) { document.getElementById("ai-bot-conversations-input")?.focus(); }
      this.menuElement?.removeAttribute("open");
    } finally { if (!this.isDestroying && !this.isDestroyed) { this.busy = false; } }
  }
  @action conversations() { return this.navigate(HOME); }
  @action newConversation() { return this.navigate(HOME, true); }
  @action visit(event) {
    // Keep modified clicks/native new-tab semantics; these do not discard this tab's draft.
    if (event.ctrlKey || event.metaKey || event.shiftKey || event.altKey || event.button !== 0) { return; }
    event.preventDefault();
    return this.navigate(event.currentTarget.getAttribute("href"));
  }
  @action menuToggle(event) {
    this.menuElement = event.currentTarget;
    if (!this.menuElement.open) { return; }
    const detail = { version: 1, surface: this.capabilities.viewport.sm ? "desktop" : "mobile", rows: null };
    document.dispatchEvent(new CustomEvent("je-nav:destinations:request", {detail}));
    this.rows = Array.isArray(detail.rows) ? detail.rows : [];
  }
  @action keydown(event) {
    if (event.key === "Escape" && this.menuElement?.open) {
      this.menuElement.removeAttribute("open");
      this.menuElement.querySelector("summary")?.focus();
      event.stopPropagation();
    }
  }
  <template>
    {{#if this.visible}}
      <nav class="vcai-conversation-navigation" aria-label={{this.conversationsLabel}} {{on "keydown" this.keydown}}>
        {{#if this.state.landing}}
          <span class="vcai-conversation-navigation__context">{{this.conversationsLabel}}</span>
        {{else}}
          <DButton @translatedLabel={{this.conversationsLabel}} @action={{this.conversations}} @disabled={{this.busy}} />
        {{/if}}
        <DButton @translatedLabel={{this.newLabel}} @action={{this.newConversation}} @disabled={{this.busy}} />
        <details class="vcai-conversation-navigation__menu" {{on "toggle" this.menuToggle}}>
          <summary>{{this.menuLabel}}</summary>
          <div class="vcai-conversation-navigation__links">
            <a href="/feed" {{on "click" this.visit}}>{{this.feedLabel}}</a>
            {{#each this.rows as |group|}}
              {{#if group.href}}
                <a href={{group.href}} {{on "click" this.visit}}>{{group.label}}</a>
              {{else}}
                <details>
                  <summary>{{group.label}}</summary>
                  {{#each group.children as |row|}}
                    <a href={{row.href}} {{on "click" this.visit}}>{{row.label}}</a>
                  {{/each}}
                </details>
              {{/if}}
            {{/each}}
          </div>
        </details>
      </nav>
    {{/if}}
  </template>
}
