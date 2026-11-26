/**
 * The timeline of every spot, newest first, under a heading for each day: the newest 500 entries, or the 500 newest
 * that hold each word typed in the sheet. Its card shows the newest entry, and with Show in search on, the panel's
 * search shows the three newest that hold the words. Return pastes a text, a picture or a file into the front app and
 * opens a link, ⌘C copies, ⌘⌫ forgets the entry, with a toast that puts it back, and Tab hands it to a spot that takes it.
 */

/** The value of a line of a block, with its escapes undone. */
function unescape(value) {
  return value.replace(/\\(\\|n)/g, (_, c) => (c === "n" ? "\n" : "\\"))
}

/** The entries that `openspot timeline list` printed, each as an object of its keys, with the count of its files. */
function entries(text) {
  return text
    .split("\n\n")
    .filter((block) => block.trim() !== "")
    .map((block) => {
      const entry = { files: 0 }
      for (const line of block.split("\n")) {
        const at = line.indexOf("=")
        if (at <= 0) continue
        const key = line.slice(0, at)
        if (key === "file") entry.files++
        if (!(key in entry)) entry[key] = unescape(line.slice(at + 1))
      }
      return entry
    })
    .filter((entry) => entry.item)
}

/** What `openspot timeline <words>` printed; it throws when the command fails. */
function timeline(...words) {
  const answer = openspot.call(["timeline", ...words])
  if (answer.code !== 0) throw new Error(answer.errors || `openspot timeline ${words[0]} failed.`)
  return answer.stdout
}

/** The entries of the timeline, newest first, that hold each word of `text`. */
function listed(limit, text) {
  const words = ["list", "--all", "--limit", String(limit)]
  return entries(timeline(...(text ? [...words, "--text", text] : words)))
}

/** Whether a path names a picture. */
function isPicture(path) {
  return /\.(png|jpe?g|gif|heic|tiff|webp|bmp)$/i.test(path || "")
}

/** The name of the spot an entry came from, such as `Clipboard`. */
function source(entry) {
  const name = (entry.spot || "").replace(/.*\//, "")
  return name.charAt(0).toUpperCase() + name.slice(1)
}

/** The time of an entry, such as `09:57`. */
function time(entry) {
  return (entry.at || "").slice(11, 16)
}

/** What an entry holds, such as `3 lines`, `github.com` or `Image`. */
function holds(entry) {
  if (entry.kind === "url") return (entry.url || "").replace(/^[a-zA-Z]+:\/\//, "").replace(/[/?#].*/, "")
  if (entry.kind === "file") return entry.files > 1 ? `${entry.files} files` : isPicture(entry.file) ? "Image" : "File"
  if (entry["text.file"]) return "Long text"
  const text = entry.text || ""
  const lines = text.split("\n").length
  return lines > 1 ? `${lines} lines` : `${[...text].length} characters`
}

/** The icon of an entry: its own, else that of its kind, a picture as itself and a colour such as `#ff3b30` as a square of it. */
function icon(entry) {
  if (entry.icon) return entry.icon
  if (entry.kind === "url") return "link"
  if (entry.kind === "file") return isPicture(entry.file) && entry.files === 1 ? entry.file : "doc"
  return /^#[0-9a-fA-F]{6}$/.test(entry.text || "") ? entry.text.toLowerCase() : "text.alignleft"
}

/** The row of an entry, with the detail under its title. */
function row(entry, detail) {
  const kind = entry.kind
  const long = kind === "text" && entry["text.file"]
  const value = { item: entry.item, title: entry.title, detail, icon: icon(entry), kind }
  if (kind === "url" || (kind === "text" && !long)) value[kind] = entry[kind]
  if (long) value.file = entry["text.file"]
  if (kind === "file") value.file = entry.file
  if (kind === "text" || kind === "url") value.keywords = (entry[kind] || "").slice(0, 200)
  value["open.title"] = kind === "url" ? "Open" : "Paste"
  return value
}

/** A day such as `2026-11-26` as a local date. */
function date(day) {
  const [year, month, number] = day.split("-").map(Number)
  return new Date(year, month - 1, number)
}

/** A local date as `2026-11-26`. */
function stamp(when) {
  const two = (number) => String(number).padStart(2, "0")
  return `${when.getFullYear()}-${two(when.getMonth() + 1)}-${two(when.getDate())}`
}

/** The heading of a day: Today, Yesterday or a date such as `Monday, November 23`. */
function heading(day, now) {
  if (day === stamp(now)) return "Today"
  if (day === stamp(new Date(now.getFullYear(), now.getMonth(), now.getDate() - 1))) return "Yesterday"
  return date(day).toLocaleDateString("en-US", { weekday: "long", month: "long", day: "numeric" })
}

/** The frame of the sheet: a group for each day, with a row for each entry, or a row that says how to fill it. */
function sheet(text) {
  const shown = listed(500, text)
  if (shown.length === 0) {
    return [
      { frame: "", recents: "false" },
      { item: "empty", title: "Copy something, and it shows here.", icon: "doc.on.clipboard", hides: ["copy", "forget"] },
    ]
  }
  const now = new Date()
  const blocks = [
    { frame: "", recents: "false", title: "Timeline" },
    { button: "copy", title: "Copy", shortcut: "cmd+c", scope: "item" },
    { button: "forget", title: "Forget", shortcut: "cmd+backspace", scope: "item", close: "false" },
    { items: "list" },
  ]
  let last = ""
  for (const entry of shown) {
    const day = (entry.at || "").slice(0, 10)
    if (day !== last) {
      blocks.push({ box: `day-${day}`, parent: "list", title: heading(day, now) })
      last = day
    }
    const from = entry.spot === "clipboard" ? "" : ` · ${source(entry)}`
    blocks.push({ ...row(entry, `${time(entry)} · ${entry.detail || holds(entry)}${from}`), parent: `day-${day}` })
  }
  return blocks
}

/** The card: the newest entry. */
function card() {
  const [entry] = listed(1)
  return [entry ? { frame: "", title: entry.title, detail: `${source(entry)} · ${time(entry)}` } : { frame: "" }]
}

/** The inputs of the entry acts for the pressed row. */
function pressed(input) {
  return { kind: input["item.kind"], text: input["item.text"], url: input["item.url"], file: input["item.file"] }
}

export default {
  async show({ event }, env) {
    timeline("keep", String(env.settings.keep || "").replace(/\D/g, "") || "30")
    return event === "panel.open" ? card() : sheet("")
  },
  "sheet.text"({ value }) {
    return sheet(value || "")
  },
  search({ text }) {
    const isOn = openspot.call(["setting", "get", "--spot", "openspot/timeline", "in-search"]).stdout.trim() === "true"
    if (!isOn) return []
    return listed(3, text).map((entry) => row(entry, `Timeline · ${source(entry)} · ${time(entry)}`))
  },
  async command(_, env) {
    await env.open("openspot/timeline")
  },
  async press(input, env) {
    if (input.item === "empty") return
    await env.entry.use(pressed(input))
  },
  async copy(input, env) {
    await env.entry.copy(pressed(input))
    await env.toast("Copied.")
  },
  async forget({ item }, env) {
    timeline("forget", item)
    env.cache.set("forgotten", item)
    await env.toast("Forgot it. Click to put it back.", { id: "forgot", action: "restore" })
    return sheet("")
  },
  async restore(_, env) {
    const kept = env.cache.get("forgotten")
    env.cache.set("forgotten", "")
    openspot.call(["toast", "--remove", "forgot"])
    if (kept && kept.value) timeline("restore", kept.value)
  },
  async pause(_, env) {
    timeline("pause", "1h")
    await env.toast("Timeline keeps nothing for an hour.")
  },
  async resume(_, env) {
    timeline("resume")
    await env.toast("Timeline keeps what you copy again.")
  },
}
