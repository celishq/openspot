/** The rows of the timeline in the panel's search, when Show in search is on in the Settings of Timeline: the first
 * three rows that the Timeline sheet shows for the words. */

/** Whether the person turned on Show in search. */
function isOn() {
  return openspot.call(["setting", "get", "--spot", "openspot/timeline", "in-search"]).stdout.trim() === "true"
}

/** The value of a line of a block, with its escapes undone. */
function unescape(value) {
  return value.replace(/\\(\\|n)/g, (_, c) => (c === "n" ? "\n" : "\\"))
}

/** The blocks that a run printed, each as an object of its keys. */
function entries(text) {
  return text
    .split("\n\n")
    .filter((block) => block.trim() !== "")
    .map((block) => {
      const entry = {}
      for (const line of block.split("\n")) {
        const at = line.indexOf("=")
        if (at > 0 && !(line.slice(0, at) in entry)) entry[line.slice(0, at)] = unescape(line.slice(at + 1))
      }
      return entry
    })
}

export default {
  search({ text }) {
    if (!isOn()) return []
    const sheet = openspot.call(["spot", "run", "openspot/timeline", "sheet.text", `value=${text}`, "limit=3"])
    if (sheet.code !== 0) return []
    return entries(sheet.stdout)
      .filter((row) => row.item && row.item !== "empty")
      .map(({ parent, ...row }) => ({ ...row, detail: `Timeline · ${row.detail}` }))
  },
  async press(input, env) {
    await env.timeline.copy({
      kind: input["item.kind"],
      text: input["item.text"],
      url: input["item.url"],
      file: input["item.file"],
    })
  },
}
