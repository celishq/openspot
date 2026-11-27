/** The timeline of every spot, newest first, under a heading for each day, a page of 60 entries at a time: the newest
 * ones, or the best that hold each word typed in the sheet, as Openspot's search ranks them. Return copies an entry, ⌘Return pastes it
 * into the front app, ⌘⌫ forgets it, with a toast that puts it back, and Tab hands it to a spot that takes it. A row
 * holds at most the start of a long text, so a copy pipes the whole value that `timeline get` prints into
 * `clipboard copy`. */

const limit = 60
const heldText = 2000
const weekdays = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
const months = ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"]

/** The blocks that `openspot timeline list` printed, each as its keys with their values still escaped, and its files. */
function entries(text) {
  return text
    .split("\n\n")
    .filter((block) => block.trim() !== "")
    .map((block) => {
      const entry = { files: [] }
      for (const line of block.split("\n")) {
        const at = line.indexOf("=")
        if (at <= 0) continue
        const key = line.slice(0, at)
        const value = line.slice(at + 1)
        if (key === "file") entry.files.push(value)
        if (!(key in entry)) entry[key] = value
      }
      return entry
    })
}

/** The date of a day, such as `2026-11-26`, in the Mac's time zone. */
function dayOf(date) {
  const two = (number) => String(number).padStart(2, "0")
  return `${date.getFullYear()}-${two(date.getMonth() + 1)}-${two(date.getDate())}`
}

/** The heading of a day: Today, Yesterday, or its weekday and date. */
function dayTitle(day, now) {
  if (day === dayOf(now)) return "Today"
  if (day === dayOf(new Date(now.getFullYear(), now.getMonth(), now.getDate() - 1))) return "Yesterday"
  const [year, month, date] = day.split("-").map(Number)
  return `${weekdays[new Date(year, month - 1, date).getDay()]}, ${months[month - 1]} ${date}`
}

/** Whether a path is a picture or a video, which shows its own image as its icon. */
function showsItself(path) {
  return /\.(png|jpe?g|gif|heic|tiff|webp|bmp|mov|mp4|m4v)$/i.test(path)
}

/** The words of what an entry holds, such as `github.com`, `3 lines` or `Image`. */
function what(entry) {
  const value = entry[entry.kind] || ""
  if (entry.kind === "url") return value.replace(/^[a-zA-Z]+:\/\//, "").replace(/[/?#].*/, "")
  if (entry.kind === "file") {
    if (entry.files.length > 1) return `${entry.files.length} files`
    if (/\.(png|jpe?g|gif|heic|tiff|webp|bmp)$/i.test(value)) return "Image"
    return /\.(mov|mp4|m4v)$/i.test(value) ? "Video" : "File"
  }
  if (entry["text.file"]) return "Long text"
  const lines = (value.match(/\\n/g) || []).length + 1
  return lines > 1 ? `${lines} lines` : `${value.length} characters`
}

/** The name of a spot, from its id, such as Notes from `notes` or `me/notes`. */
function source(spot) {
  const name = spot.replace(/.*\//, "")
  return name.charAt(0).toUpperCase() + name.slice(1)
}

/** The start of an escaped value, cut where no escape is split. */
function start(value) {
  const cut = value.slice(0, heldText)
  return cut.endsWith("\\") && !cut.endsWith("\\\\") ? cut.slice(0, -1) : cut
}

/** The lines of one row. */
function row(entry, day) {
  const kind = entry.kind
  const value = entry[kind] || ""
  const time = (entry.at || "").slice(11, 16)
  let detail = `${time} · ${entry.detail || what(entry)}`
  if (entry.spot !== "clipboard") detail += ` · ${source(entry.spot)}`
  const color = /^#([0-9a-fA-F]{3}|[0-9a-fA-F]{6})$/.test(value) ? value.toLowerCase() : "textformat"
  const icon = entry.icon || (kind === "url" ? "link" : kind === "file" ? (showsItself(value) && entry.files.length === 1 ? value : "doc") : color)
  const lines = [`item=${entry.item}`, `parent=day-${day}`, `title=${entry.title}`, `detail=${detail}`, `icon=${icon}`, `kind=${kind}`]
  if (kind === "url" || (kind === "text" && !entry["text.file"])) lines.push(`${kind}=${start(value)}`)
  if (kind === "text" && entry["text.file"]) lines.push(`file=${entry["text.file"]}`)
  if (kind === "text" || kind === "url") lines.push(`keywords=${value.slice(0, 200)}`)
  if (kind === "file") lines.push(`file=${value}`)
  lines.push("open.title=Copy")
  if (entry["peek.file"]) lines.push(`peek.file=${entry["peek.file"]}`)
  return lines.join("\n")
}

/** The frame of the entries that hold the words, or the newest ones, after the entry of `after` for a next page. */
function list(words, count, after) {
  const search = words ? ["--search", words] : []
  const next = after ? ["--after", after] : []
  const listed = run(["timeline", "list", "--all", "--limit", String(count || limit), ...search, ...next])
  const now = new Date()
  const blocks = ["frame=\nrecents=false"]
  let last = ""
  for (const entry of entries(listed).filter((entry) => entry.item)) {
    if (blocks.length === 1) {
      blocks[0] += "\ntitle=Timeline"
      blocks.push("button=press\ntitle=Copy\nscope=item")
      blocks.push("button=paste\ntitle=Paste\nshortcut=cmd+return\nscope=item")
      blocks.push("button=forget\ntitle=Forget\nshortcut=cmd+backspace\nscope=item\nclose=false")
      blocks.push("items=list")
    }
    const day = (entry.at || "").slice(0, 10)
    if (day !== last) {
      blocks.push(`box=day-${day}\nparent=list\ntitle=${dayTitle(day, now)}`)
      last = day
    }
    blocks.push(row(entry, day))
  }
  if (!last && after) return ""
  if (!last) {
    blocks.push(words ? `item=empty\ntitle=Nothing you copied holds “${words}”.\nicon=magnifyingglass\nhides=copy\nhides=forget` : "item=empty\ntitle=Copy something, and it shows here.\nicon=doc.on.clipboard\nhides=copy\nhides=forget")
  }
  return blocks.join("\n\n") + "\n"
}

/** Runs an `openspot` command, and fails with what it said when it fails. */
function run(words) {
  const ran = openspot.call(words)
  if (ran.code !== 0) throw new Error((ran.stderr || ran.stdout || "").trim() || `Timeline could not run ${words.join(" ")}.`)
  return ran.stdout
}

/** Copies the entry of a row: its file as Finder does, or the whole text or link that `timeline get` prints. */
function copy(input) {
  if (input["item.kind"] === "file") return run(["clipboard", "copy", input["item.file"]])
  const copied = openspot.call(["clipboard", "copy"], run(["timeline", "get", input.item]))
  if (copied.code !== 0) throw new Error((copied.stderr || copied.stdout || "").trim() || "Timeline could not copy that entry.")
}

export default {
  show(input, env) {
    const days = String(env.settings.keep ?? "").replace(/[^0-9]/g, "")
    if (days) run(["timeline", "keep", days])
    return list("")
  },
  "sheet.text"({ value = "", limit: count }) {
    return list(value, count)
  },
  "sheet.more"({ after, value = "" }) {
    return list(value, limit, after)
  },
  command() {
    run(["spot", "open", "openspot/timeline"])
  },
  press(input) {
    if (!input.item || input.item === "empty") return
    copy(input)
    run(["toast", "Copied."])
  },
  paste(input) {
    if (!input.item || input.item === "empty") return
    copy(input)
    run(["clipboard", "paste"])
  },
  forget({ item }, env) {
    run(["timeline", "forget", item])
    env.cache.set("forgotten", item)
    run(["toast", "--id", "forgot", "--action", "restore", "Forgot it. Click to put it back."])
  },
  restore(input, env) {
    const item = env.cache.get("forgotten")?.value
    env.cache.set("forgotten", "")
    run(["toast", "--remove", "forgot"])
    if (item) run(["timeline", "restore", item])
  },
  pause() {
    run(["timeline", "pause", "1h"])
    run(["toast", "Timeline keeps nothing for an hour."])
  },
  resume() {
    run(["timeline", "resume"])
    run(["toast", "Timeline keeps what you copy again."])
  },
}
