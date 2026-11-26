/** The rows of the timeline in the panel's search, when Show in search is on in the Settings of Timeline. */

/** Whether the person turned on Show in search. */
function isOn() {
  return openspot.call(["setting", "get", "--spot", "openspot/timeline", "search"]).stdout.trim() === "true"
}

/** The value of a line of a block, with its escapes undone. */
function unescape(value) {
  return value.replace(/\\(\\|n)/g, (_, c) => (c === "n" ? "\n" : "\\"))
}

/** The entries that `openspot timeline list` printed, each as an object of its keys. */
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

/** The source and the time of an entry, such as `Clipboard · 10:12`. */
function detail(entry) {
  const name = (entry.spot || "").replace(/.*\//, "")
  return `Timeline · ${name.charAt(0).toUpperCase()}${name.slice(1)} · ${(entry.at || "").slice(11, 16)}`
}

export default {
  search({ text }) {
    if (!isOn()) return []
    const listed = openspot.call(["timeline", "list", "--all", "--limit", "3", "--text", text])
    if (listed.code !== 0) return []
    return entries(listed.stdout).map((entry) => {
      const kind = "url" in entry ? "url" : "file" in entry ? "file" : "picture" in entry ? "picture" : "text"
      const row = { item: entry.item, title: entry.title, detail: detail(entry), kind, "open.title": kind === "url" ? "Open" : "Paste" }
      if (kind === "picture") {
        row.icon = entry.picture
        row.file = entry.picture
      } else if (kind === "file") {
        row.icon = "doc"
        row.file = entry.file
      } else {
        row.icon = kind === "url" ? "link" : "text.alignleft"
        row[kind] = entry[kind]
      }
      if (entry["text.file"]) row.whole = entry["text.file"]
      return row
    })
  },
  async press(input, env) {
    const kind = input["item.kind"]
    await env.timeline.use({
      kind: kind === "picture" ? "file" : kind,
      text: input["item.text"],
      url: input["item.url"],
      file: input["item.file"],
      whole: input["item.whole"],
    })
  },
}
