import Component from "@glimmer/component";
import { registerDestructor } from "@ember/destroyable";
import { getOwner } from "@ember/owner";
import { schedule } from "@ember/runloop";
import { service } from "@ember/service";

// Shown while a reply is streaming and no tool call is in flight. One line, no rotation:
// the model really is working, and that is all this can honestly claim.
const WAITING_LINE_FALLBACK = "Thinking this through";

const SWAP_FADE_MS = 180;
const LEAVE_FADE_MS = 180;

function listSetting(value) {
  return String(value || "")
    .split("|")
    .map((entry) => entry.trim())
    .filter(Boolean);
}

function toolLabels(value) {
  const labels = new Map();
  listSetting(value).forEach((entry) => {
    const separator = entry.indexOf("::");
    if (separator < 1) {
      return;
    }
    const summary = entry.slice(0, separator).trim();
    const label = entry.slice(separator + 2).trim();
    if (summary && label) {
      labels.set(summary, label);
    }
  });
  return labels;
}

export default class VcaiResponseStatus extends Component {
  @service appEvents;

  observer = null;
  observedElement = null;
  node = null;
  phraseElement = null;
  swapTimer = null;
  leaveTimer = null;
  activeLine = null;
  reduceMotion = false;
  sessionKey = null;
  proseStarted = false;
  framePending = false;

  constructor() {
    super(...arguments);

    if (
      settings.vcai_enabled !== true ||
      settings.vcai_response_status_enabled !== true
    ) {
      return;
    }

    this.onPageChanged = this.onPageChanged.bind(this);
    this.appEvents.on("page:changed", this, this.onPageChanged);
    schedule("afterRender", this, this.onPageChanged);
    registerDestructor(this, () => this.teardown());
  }

  get currentTopic() {
    return (
      this.args?.outletArgs?.model ||
      getOwner(this).lookup("controller:topic")?.model ||
      null
    );
  }

  onPageChanged() {
    this.detachObserver();
    this.deactivate();
    this.resetSession();

    const topic = this.currentTopic;
    if (!topic?.is_bot_pm) {
      return;
    }

    this.reduceMotion =
      window.matchMedia?.("(prefers-reduced-motion: reduce)")?.matches === true;
    this.attachObserver();
    this.scheduleScan();
  }

  teardown() {
    this.appEvents.off("page:changed", this, this.onPageChanged);
    this.detachObserver();
    this.deactivate();
  }

  attachObserver() {
    this.observedElement =
      document.querySelector(".topic-area") ||
      document.getElementById("main-outlet") ||
      document.body;
    this.observer = new MutationObserver(() => this.scheduleScan());
    this.observer.observe(this.observedElement, {
      childList: true,
      subtree: true,
      attributes: true,
      attributeFilter: ["class"],
    });
  }

  detachObserver() {
    this.observer?.disconnect();
    this.observer = null;
    this.observedElement = null;
  }

  resetSession() {
    this.sessionKey = null;
    this.proseStarted = false;
  }

  scheduleScan() {
    if (this.framePending) {
      return;
    }
    this.framePending = true;
    requestAnimationFrame(() => {
      this.framePending = false;
      this.scan();
    });
  }

  streamingPost() {
    const scope = this.observedElement || document;
    return (
      scope.querySelector('article[id^="post_"].streaming') ||
      scope.querySelector('.streaming[id^="post_"]')
    );
  }

  scan() {
    const post = this.streamingPost();
    if (!post) {
      this.resetSession();
      this.deactivate();
      return;
    }

    const key = post.id || post.getAttribute("data-post-id") || "active";
    if (key !== this.sessionKey) {
      this.sessionKey = key;
      this.proseStarted = false;
    }

    if (this.proseStarted) {
      return;
    }

    const cooked = post.querySelector(".cooked");
    if (!cooked) {
      return;
    }

    if (this.hasProse(cooked)) {
      this.proseStarted = true;
      this.deactivate();
      return;
    }

    this.activate(post, cooked);
    this.updateStatusLine(post);
  }

  hasProse(cooked) {
    const clone = cooked.cloneNode(true);
    clone
      .querySelectorAll("details.ai-thinking, .progress-dot")
      .forEach((node) => node.remove());
    return clone.textContent.trim().length > 0;
  }

  updateStatusLine(post) {
    const strongs = post.querySelectorAll("details.ai-thinking strong");
    const last = strongs.length ? strongs[strongs.length - 1] : null;

    if (!last) {
      this.setStatus(this.waitingLine);
      return;
    }

    // Core renders every tool call as `**summary**` then the details line. While a call
    // is in flight the details half is empty, so the bold line stands alone in its
    // paragraph; when the call returns, the committed record puts the outcome beside it.
    // The in-flight placeholder is always appended last, so: a bare last bold line means
    // a call is running now, and a last bold line with text beside it means the last call
    // has already finished and nothing is running.
    const text = last.textContent.trim();
    const parent = last.parentElement;
    const inFlight = !parent || parent.textContent.trim() === text;

    if (!text || !inFlight) {
      this.setStatus(this.waitingLine);
      return;
    }

    // The server's own wording is the default. The mapping table remains only for tools
    // whose summary text we do not control - core's "Search Google" and the like - and an
    // unmapped summary now passes through instead of falling back to an invented phrase.
    const mappings = toolLabels(settings.vcai_response_status_tool_labels);
    this.setStatus(mappings.get(text) || text);
  }

  activate(post, cooked) {
    if (this.leaveTimer) {
      clearTimeout(this.leaveTimer);
      this.leaveTimer = null;
      this.node?.classList.remove("vcai-response-status--leaving");
    }

    if (this.node && !post.contains(this.node)) {
      this.removeNode();
    }
    if (this.node) {
      return;
    }

    const wrapper = document.createElement("div");
    wrapper.className = "vcai-response-status";
    wrapper.setAttribute("role", "status");
    wrapper.setAttribute("aria-live", "polite");
    wrapper.setAttribute("aria-atomic", "true");

    const ring = document.createElement("span");
    ring.className = "vcai-response-status__ring";
    ring.setAttribute("aria-hidden", "true");

    const phrase = document.createElement("span");
    phrase.className = "vcai-response-status__phrase";

    wrapper.append(ring, phrase);
    cooked.parentElement?.insertBefore(wrapper, cooked);
    this.node = wrapper;
    this.phraseElement = phrase;
    this.activeLine = null;
    this.setStatus(this.waitingLine);
  }

  removeNode() {
    if (this.swapTimer) {
      clearTimeout(this.swapTimer);
      this.swapTimer = null;
    }
    this.node?.remove();
    this.node = null;
    this.phraseElement = null;
  }

  deactivate() {
    this.activeLine = null;
    if (!this.node) {
      return;
    }

    if (this.leaveTimer) {
      return;
    }

    if (this.reduceMotion) {
      this.removeNode();
      return;
    }

    const leaving = this.node;
    leaving.classList.add("vcai-response-status--leaving");
    this.leaveTimer = setTimeout(() => {
      this.leaveTimer = null;
      if (this.node === leaving) {
        this.removeNode();
      } else {
        leaving.remove();
      }
    }, LEAVE_FADE_MS);
  }

  get waitingLine() {
    return (
      String(settings.vcai_response_status_waiting_line || "").trim() ||
      WAITING_LINE_FALLBACK
    );
  }

  setStatus(text) {
    if (!text || this.activeLine === text) {
      return;
    }
    this.activeLine = text;
    this.setPhrase(text);
  }

  setPhrase(text) {
    if (!this.phraseElement) {
      return;
    }

    if (this.reduceMotion) {
      this.phraseElement.textContent = text;
      return;
    }

    if (this.swapTimer) {
      clearTimeout(this.swapTimer);
    }
    this.phraseElement.classList.add("vcai-response-status__phrase--swapping");
    this.swapTimer = setTimeout(() => {
      this.swapTimer = null;
      if (this.phraseElement) {
        this.phraseElement.textContent = text;
        this.phraseElement.classList.remove(
          "vcai-response-status__phrase--swapping"
        );
      }
    }, SWAP_FADE_MS);
  }

  <template></template>
}
