import VcaiHeaderControl from "./vcai-header-control";

// Memories: visible whenever the memory module is mounted on an AI route.
export default class VcaiHeaderMemory extends VcaiHeaderControl {
  kind = "memory";
  icon = "brain";
  labelKey = "vcai_header.memories";
  openKey = "vcai_header.open_memories";
  closeKey = "vcai_header.close_memories";
  controls = "vcai-memory-panel";

  readState() {
    const classes = document.body.classList;
    return {
      visible: classes.contains("vcai-memory"),
      open: classes.contains("vcai-memory--open"),
    };
  }
}
