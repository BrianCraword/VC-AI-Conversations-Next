import { apiInitializer } from "discourse/lib/api";
import VcaiResponseStatus from "../components/vcai-response-status";

export default apiInitializer((api) => {
  const root = document.documentElement;

  if (
    settings.vcai_enabled !== true ||
    settings.vcai_response_status_enabled !== true
  ) {
    root.classList.remove(
      "vcai-response-status-enabled",
      "vcai-response-status-hide-trailing"
    );
    return;
  }

  root.classList.add("vcai-response-status-enabled");
  root.classList.toggle(
    "vcai-response-status-hide-trailing",
    settings.vcai_response_status_hide_streaming_trailing_dot === true
  );

  api.renderInOutlet("topic-area-bottom", VcaiResponseStatus);
});
