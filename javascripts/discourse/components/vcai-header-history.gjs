import VcaiHeaderControl from "./vcai-header-control";

// History: visible only while the history module is mounted AND the rail is
// not persistent (desktop shows the rail itself, so no control is needed).
export default class VcaiHeaderHistory extends VcaiHeaderControl {
  kind = "history";
  icon = "clock-rotate-left";
  labelKey = "vcai_header.history";
  openKey = "vcai_header.open_history";
  closeKey = "vcai_header.close_history";
  controls = "main-outlet-wrapper";

  readState() {
    const classes = document.body.classList;
    return {
      visible:
        classes.contains("vcai-history") &&
        !classes.contains("vcai-history--persistent"),
      open: classes.contains("vcai-history--drawer-open"),
    };
  }
}
