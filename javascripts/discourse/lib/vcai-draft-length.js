// Match the native hidden-submit payload, including upload separators.
export function draftPayload(input, uploadMarkdown = []) {
  const raw = String(input || "");
  return uploadMarkdown.length
    ? raw + "\n\n" + uploadMarkdown.map((text) => text + "\n").join("")
    : raw;
}

export function draftLengthState(input, configuredLimit) {
  const limit = Number(configuredLimit);
  const count = Array.from(String(input || "")).length;
  const validLimit = Number.isInteger(limit) && limit > 0;
  return {
    count,
    limit: validLimit ? limit : null,
    near: validLimit && count >= Math.ceil(limit * 0.9),
    over: validLimit && count > limit,
  };
}
