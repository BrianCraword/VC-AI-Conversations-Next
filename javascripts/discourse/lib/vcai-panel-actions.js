// Read only the panel-owner classes; no additional persistence or drawer state.
export function panelActions(classes) {
  return {
    historyAvailable: classes.contains("vcai-history") && !classes.contains("vcai-history--persistent"),
    historyOpen: classes.contains("vcai-history--drawer-open"),
    memoryAvailable: classes.contains("vcai-memory"),
    memoryOpen: classes.contains("vcai-memory--open"),
  };
}
