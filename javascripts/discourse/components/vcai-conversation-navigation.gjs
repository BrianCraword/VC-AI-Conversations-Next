import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { getOwner } from "@ember/owner";
import { service } from "@ember/service";
import { registerDestructor } from "@ember/destroyable";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import willDestroy from "@ember/render-modifiers/modifiers/will-destroy";
import { on } from "@ember/modifier";
import icon from "discourse/helpers/d-icon";
import { i18n } from "discourse-i18n";
import { routeState, onRouteState } from "../lib/vcai-route-state";
import { panelActions } from "../lib/vcai-panel-actions";
import { eligibleNavigation, hasDraftContent } from "../lib/vcai-navigation-policy";

const HOME = "/discourse-ai/ai-bot/conversations";
export default class VcaiConversationNavigation extends Component {
  @service currentUser;
  @service router;
  @service appEvents;
  @service dialog;
  @service capabilities;
  @tracked rows = [];
  @tracked sharedExplore = false;
  @tracked state = routeState();
  @tracked path = "";
  @tracked busy = false;
  @tracked historyAvailable = false;
  @tracked historyOpen = false;
  @tracked memoryAvailable = false;
  @tracked memoryOpen = false;

  constructor() {
    super(...arguments);
    this.sync();
    this.historyObserver = new MutationObserver(() => this.syncPanels());
    this.syncPanels();
    this.historyObserver.observe(document.body, {attributes:true, attributeFilter:["class"]});
    const unsubscribe = onRouteState(() => this.sync());
    this.changed = () => this.sync();
    this.router.on("routeDidChange", this.changed);
    this.beforeNavigate = event => { if (this.visible && !this.canLeave()) { event.preventDefault(); } };
    document.addEventListener("je-nav:before-navigate", this.beforeNavigate);
    registerDestructor(this, () => {
      unsubscribe();
      this.historyObserver.disconnect();
      document.removeEventListener("je-nav:before-navigate", this.beforeNavigate);
      this.router.off("routeDidChange", this.changed);
    });
  }
  sync() {
    this.state = routeState();
    this.path = this.router.currentURL || "";
    this.rows = [];
    this.menuElement?.removeAttribute("open");
    const detail = { version: 1, surface: this.capabilities.viewport.sm ? "desktop" : "mobile" };
    document.dispatchEvent(new CustomEvent("je-nav:destinations:request", {detail}));
    this.sharedExplore = detail.sharedExplore === true;
  }
  syncPanels() {
    const panels = panelActions(document.body.classList);
    this.historyAvailable = panels.historyAvailable;
    this.historyOpen = panels.historyOpen;
    this.memoryAvailable = panels.memoryAvailable;
    this.memoryOpen = panels.memoryOpen;
  }
  get memoryLabel() { return i18n(themePrefix("vcai_header.memories")); }
  get memoryTitle() { return i18n(themePrefix(this.memoryOpen ? "vcai_header.close_memories" : "vcai_header.open_memories")); }
  get historyTitle() { return i18n(themePrefix(this.historyOpen ? "vcai_header.close_history" : "vcai_header.open_history")); }
  @action memory() { window.dispatchEvent(new CustomEvent("vcai:memory:toggle")); }
  get visible() {
    return eligibleNavigation({user: this.currentUser, state: this.state, path: this.path,
      topic: getOwner(this).lookup("controller:topic")?.model,
      excludedIds: settings.vcai_navigation_excluded_bot_ids});
  }
  get conversationsLabel() { return i18n(themePrefix("vcai_navigation.conversations")); }
  get newLabel() { return i18n(themePrefix("vcai_navigation.new_conversation")); }
  get menuLabel() { return i18n(themePrefix("vcai_navigation.site_menu")); }
  get shortNewLabel() { return i18n(themePrefix("vcai_navigation.new_short")); }
  get backLabel() { return i18n(themePrefix("vcai_navigation.back")); }
  get workspaceLabel() { return i18n(themePrefix("vcai_navigation.workspace")); }
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
      } finally { if (!this.isDestroying && !this.isDestroyed) { this.busy = false; } }
  }
  get historyLabel() { return i18n(themePrefix("vcai_header.history")); }
  @action history() {
    window.dispatchEvent(new CustomEvent("vcai:history:toggle"));
  }
  @action explore(event) {
    event?.stopPropagation();
    const request = new CustomEvent("je-nav:explore:open", {cancelable: true});
    document.dispatchEvent(request);
    if (!request.defaultPrevented) { this.sharedExplore = false; }
  }
  @action ready() { document.body.classList.add("vcai-navigation-ready"); }
  @action unready() { document.body.classList.remove("vcai-navigation-ready"); }
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
      <nav class="vcai-conversation-navigation {{if this.sharedExplore 'vcai-conversation-navigation--shared'}}" aria-label={{this.conversationsLabel}} {{on "keydown" this.keydown}} {{didInsert this.ready}} {{willDestroy this.unready}}>
        <span class="vcai-conversation-navigation__context">{{icon "comments"}}<span class="vcai-nav-wide">{{this.workspaceLabel}}</span><span class="vcai-nav-short">AI</span></span>
        {{#unless this.state.landing}}
          <button type="button" class="vcai-nav-action vcai-nav-new" aria-label={{this.newLabel}} title={{this.newLabel}} disabled={{this.busy}} {{on "click" this.newConversation}}>{{icon "plus"}}<span class="vcai-nav-wide">{{this.newLabel}}</span><span class="vcai-nav-short">{{this.shortNewLabel}}</span></button>
        {{/unless}}
        {{#if this.sharedExplore}}
          <button type="button" class="vcai-nav-action vcai-nav-explore" aria-label={{this.menuLabel}} title={{this.menuLabel}} {{on "click" this.explore}}>{{icon "compass"}}<span>{{this.menuLabel}}</span></button>
        {{else}}
        <details class="vcai-conversation-navigation__menu" {{on "toggle" this.menuToggle}}>
          <summary aria-label={{this.menuLabel}} title={{this.menuLabel}}>{{icon "compass"}}<span>{{this.menuLabel}}</span></summary>
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
        {{/if}}
        {{#if this.historyAvailable}}
          <button type="button" class="vcai-nav-action vcai-nav-history" aria-label={{this.historyLabel}} title={{this.historyTitle}} aria-expanded={{if this.historyOpen "true" "false"}} {{on "click" this.history}}>{{icon "clock-rotate-left"}}<span>{{this.historyLabel}}</span></button>
        {{/if}}
        {{#if this.memoryAvailable}}
          <button type="button" class="vcai-nav-action vcai-nav-memory" aria-label={{this.memoryLabel}} title={{this.memoryTitle}} aria-expanded={{if this.memoryOpen "true" "false"}} aria-controls="vcai-memory-panel" {{on "click" this.memory}}>{{icon "brain"}}<span>{{this.memoryLabel}}</span></button>
        {{/if}}
      </nav>
    {{/if}}
  </template>
}
