// VC AI Conversations Next — shared route state
//
// One observer, one truth. Every module (workspace, history, memory, header
// controls) used to decide on its own whether the page was the AI landing or
// an AI thread, using onPageChange plus a couple of fixed-delay retries.
// Discourse AI adds `ai-bot-conversations-page` / `has-ai-bot-docked-composer`
// to <body> after its own render, and on a hard load that lands after the
// last retry — so nothing applied until an unrelated resize or mutation
// happened to re-run a module. This file replaces those heuristics with a
// body-class observer that publishes the state to every subscriber.
//
// The route classes are set by Discourse AI itself, so observing them is
// observing the truth rather than guessing at timing.

const LANDING_CLASS = "ai-bot-conversations-page";
const THREAD_CLASS = "has-ai-bot-docked-composer";

const subscribers = new Set();
let installed = false;
let current = { landing: false, thread: false, eligible: false };
let queued = false;
let queuedForce = false;

function compute() {
  const classes = document.body.classList;
  const landing = classes.contains(LANDING_CLASS);
  const thread = classes.contains(THREAD_CLASS);
  return { landing, thread, eligible: landing || thread };
}

function same(a, b) {
  return a.landing === b.landing && a.thread === b.thread;
}

function publish() {
  subscribers.forEach((fn) => {
    try {
      fn(current);
    } catch (error) {
      // eslint-disable-next-line no-console
      console.error("[vcai] route-state subscriber failed", error);
    }
  });
}

function refresh(force = false) {
  const next = compute();
  const changed = !same(next, current);
  current = next;
  if (changed || force) {
    publish();
  }
}

// Coalesce bursts into one refresh. A macrotask, not requestAnimationFrame:
// rAF never fires in a hidden tab, and a forced publish must not be lost
// because an unforced one was already queued ahead of it.
function scheduleRefresh(force = false) {
  queuedForce = queuedForce || force;
  if (queued) {
    return;
  }
  queued = true;
  setTimeout(() => {
    queued = false;
    const forced = queuedForce;
    queuedForce = false;
    refresh(forced);
  }, 0);
}

/** Current state without subscribing. Always computed live. */
export function routeState() {
  current = compute();
  return current;
}

/**
 * Subscribe to state changes. The callback fires on every real transition
 * (landing ↔ thread ↔ neither) and on every page change, so a subscriber can
 * treat it as "re-apply now". Returns an unsubscribe function.
 */
export function onRouteState(callback) {
  subscribers.add(callback);
  return () => subscribers.delete(callback);
}

/**
 * Install the observer once per theme. Safe to call from every initializer;
 * only the first call does anything.
 */
export function ensureRouteState(api) {
  if (installed) {
    return;
  }
  installed = true;

  // Page changes always republish (force) so modules re-apply even when the
  // route class did not change — e.g. thread → thread navigation.
  api.onPageChange(() => {
    scheduleRefresh(true);
    setTimeout(() => scheduleRefresh(true), 150);
  });

  // The class change is the authoritative signal. Discourse AI sets it
  // whenever the route settles, however late that is.
  const observer = new MutationObserver(() => scheduleRefresh(false));
  observer.observe(document.body, {
    attributes: true,
    attributeFilter: ["class"],
  });

  // A tab that loaded in the background has had no frames; modules that
  // paint on requestAnimationFrame catch up the moment it becomes visible.
  document.addEventListener("visibilitychange", () => {
    if (!document.hidden) {
      scheduleRefresh(true);
    }
  });

  // First publish after every initializer has had the chance to subscribe.
  scheduleRefresh(true);
}

/**
 * Schedule work for the next paint when the tab is visible, or for the next
 * macrotask when it is hidden. requestAnimationFrame never fires in a hidden
 * tab, so a module that latches "pending" on it stays latched until the tab
 * is shown; running hidden work on a timer keeps state current either way.
 */
export function nextPaint(callback) {
  if (document.hidden) {
    setTimeout(callback, 0);
  } else {
    requestAnimationFrame(callback);
  }
}
