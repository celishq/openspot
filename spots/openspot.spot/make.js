// title=Make a spot
// icon=plus
// detail=Make a spot that does what you typed
// on=search.text \S
// answers=last
// uses=clipboard

/** The row under the results of every search. A pick copies a prompt that asks your agent to build a spot for the words. */
function main([id, picked], env) {
  if (id === "open") {
    const prompt = openspot.call(["prompt", "new", picked])
    if (prompt.code !== 0 || openspot.call(["clipboard", "copy"], prompt.stdout).code !== 0) return ""
    return openspot.frame({ toast: "Prompt copied. Paste it into your agent." })
  }
  const text = (env.OPENSPOT_VALUE || "").trim()
  if (!text) return ""
  return openspot.frame({ row: text, title: "Make a spot", detail: text, icon: "plus" })
}
