import { apiInitializer } from "discourse/lib/api";
import Navigation from "../components/vcai-conversation-navigation";
import { ensureRouteState } from "../lib/vcai-route-state";
export default apiInitializer((api) => {
  if (settings.vcai_enabled !== true || settings.vcai_navigation_enabled !== true) { return; }
  ensureRouteState(api);
  api.renderInOutlet("above-main-container", Navigation);
});
