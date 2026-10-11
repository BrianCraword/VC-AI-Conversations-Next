import { apiInitializer } from "discourse/lib/api";
import VcaiHeaderHistory from "../components/vcai-header-history";
import VcaiHeaderMemory from "../components/vcai-header-memory";
import { ensureRouteState } from "../lib/vcai-route-state";

// VC AI Conversations Next — header controls
//
// Replaces the floating History / Memories pill (VC AI Workspace Switcher
// Next). The two controls are registered as ordinary header icons so they
// read as part of Discourse's header, never as chrome floating over content.
//
//   History  → leading, before search (the slot the hamburger occupies on
//              routes where Header Mega Nav has retired it)
//   Memories → trailing, after chat
//
// Both components render nothing when their module is not mounted, so the
// header is untouched everywhere except the AI routes.

const ROOT_CLASS = "vcai-header-controls";

export default apiInitializer((api) => {
  if (settings.vcai_enabled !== true || settings.vcai_header_controls_enabled !== true) {
    return;
  }

  ensureRouteState(api);
  document.body.classList.add(ROOT_CLASS);

  const icons = api.headerIcons;

  if (icons.has("search")) {
    icons.add("vcai-history", VcaiHeaderHistory, { before: "search" });
  } else {
    icons.add("vcai-history", VcaiHeaderHistory, { before: "hamburger" });
  }

  if (icons.has("chat")) {
    icons.add("vcai-memory", VcaiHeaderMemory, { after: "chat" });
  } else {
    icons.add("vcai-memory", VcaiHeaderMemory, { before: "user-menu" });
  }
});
