// Pure admission policy. This controls UI only; server authorization is unchanged.
export function eligibleNavigation({ user, state, path, topic, excludedIds }) {
  if (!user || !state) { return false; }
  if (state.landing && path.split("?")[0] === "/discourse-ai/ai-bot/conversations") { return true; }
  if (!state.thread || !/^\/t\//.test(path) || topic?.archetype !== "private_message") { return false; }
  const parts = path.split(/[?#]/)[0].split("/");
  const routeId = /^\d+$/.test(parts[2] || "") ? parts[2] : parts[3];
  if (String(topic.id) !== routeId) { return false; }
  const participants = topic.details?.allowed_users;
  if (!Array.isArray(participants)) { return false; }
  const excluded = new Set(String(excludedIds || "").split("|").map(x => x.trim()).filter(Boolean));
  if (participants.some(p => excluded.has(String(p.id)))) { return false; }
  const bots = new Set((user.ai_enabled_chat_bots || []).map(b => String(b.id)));
  return participants.some(p => bots.has(String(p.id)));
}

export function hasDraftContent(doc) {
  const fields = doc.querySelectorAll("#ai-bot-conversations-input, .docked-composer textarea, .d-editor-input, .docked-composer [contenteditable='true'], #reply-control [contenteditable='true']");
  return [...fields].some(el => String(el.value ?? el.textContent ?? "").trim().length > 0) ||
    !!doc.querySelector(".docked-composer__upload, .docked-composer .upload-progress, #reply-control .upload-progress");
}
