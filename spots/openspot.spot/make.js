
/** The row under the results of every search. A pick copies a prompt that asks your agent to build a spot for the words. */
function main([id, picked], env, input) {
  if (id === "open") {
    const prompt = openspot.call(["prompt", "new", picked])
    if (prompt.code !== 0 || openspot.call(["clipboard", "copy"], prompt.stdout).code !== 0) return ""
    openspot.call(["toast", "Prompt copied. Paste it into your agent."])
    return ""
  }
  const text = openspot.value("event.value", input).trim()
  if (!text) return ""
  return openspot.frame({ row: text, title: "Make a spot", detail: text, icon: "plus" })
}
