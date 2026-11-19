/** The tiles of the snooze sheet in reading order: id, title, icon, and the words of a tile with no moment. */
const tiles = [
  ["hour", "In an Hour", "clock.fill"],
  ["later", "Later", "cup.and.saucer.fill"],
  ["evening", "Evening", "moon.stars.fill"],
  ["tomorrow", "Tomorrow", "sunrise.fill"],
  ["weekend", "Weekend", "sofa.fill"],
  ["week", "Next Week", "briefcase.fill"],
  ["month", "In a Month", "calendar"],
  ["someday", "Someday", "sparkles", "No date"],
  ["date", "Pick Date", "calendar.badge.clock", "Choose…"],
]

/** The hour and minute of a setting such as `8:30`, or the fallback. */
function clock(text, fallback) {
  const match = /^(\d{1,2}):(\d{2})$/.exec((text || "").trim())
  return match ? [Number(match[1]), Number(match[2])] : fallback
}

/** The choices of the person, from the settings of the call. */
function choices(input) {
  const value = (key) => openspot.value(`setting.${key}`, input).trim()
  return {
    morning: clock(value("morning"), [8, 0]),
    evening: clock(value("evening"), [19, 0]),
    later: Number(value("later")) > 0 ? Number(value("later")) : 3,
    weekend: value("weekend") === "sunday" ? 0 : 6,
  }
}

/** The day `days` after `from`, at the hour and minute. */
function at(from, days, [hour, minute]) {
  return new Date(from.getFullYear(), from.getMonth(), from.getDate() + days, hour, minute)
}

/** The moment each tile stands for at `now`, by its id, or nil for one with no moment. */
function times(now, choices) {
  const minutes = now.getHours() * 60 + now.getMinutes()
  const morning = choices.morning[0] * 60 + choices.morning[1]
  const evening = choices.evening[0] * 60 + choices.evening[1]
  const later = new Date(now.getTime() + choices.later * 3600 * 1000)
  const weekday = now.getDay()
  const isWeekend = weekday === 6 || weekday === 0
  const toWeekend = isWeekend ? (choices.weekend - weekday + 7) % 7 || 7 : (choices.weekend - weekday + 7) % 7
  const month = new Date(now.getFullYear(), now.getMonth() + 1, 1, ...choices.morning)
  const lastDay = new Date(month.getFullYear(), month.getMonth() + 1, 0).getDate()
  month.setDate(Math.min(now.getDate(), lastDay))
  return {
    hour: new Date(now.getTime() + 3600 * 1000),
    later: minutes < morning ? at(now, 0, choices.morning) : minutes >= evening ? at(now, 1, choices.morning) : later,
    evening: minutes >= evening ? at(now, 1, choices.evening) : at(now, 0, choices.evening),
    tomorrow: at(now, 1, choices.morning),
    weekend: at(now, toWeekend === 0 ? 7 : toWeekend, choices.morning),
    week: at(now, (8 - weekday) % 7 || 7, choices.morning),
    month,
  }
}

/** Two digits. */
function two(number) {
  return String(number).padStart(2, "0")
}

/** A moment as ISO 8601 in the Mac's own zone, such as `2026-11-20T08:00:00+01:00`. */
function iso(date) {
  const offset = -date.getTimezoneOffset()
  const sign = offset >= 0 ? "+" : "-"
  const zone = `${sign}${two(Math.floor(Math.abs(offset) / 60))}:${two(Math.abs(offset) % 60)}`
  return `${date.getFullYear()}-${two(date.getMonth() + 1)}-${two(date.getDate())}T${two(date.getHours())}:${two(date.getMinutes())}:00${zone}`
}

/** The words under a tile: the time today, the weekday and time within a week, else the date. */
function words(date, now) {
  const time = `${date.getHours()}:${two(date.getMinutes())}`
  const days = Math.round((at(date, 0, [0, 0]) - at(now, 0, [0, 0])) / 86400000)
  if (days === 0) return time
  if (days < 7) return `${date.toLocaleDateString("en-US", { weekday: "short" })} ${time}`
  return date.toLocaleDateString("en-US", { month: "short", day: "numeric" })
}

/** The sheet: a grid of tiles, three in a row, each with its icon, its title and the time it stands for. Pick Date
 * opens the page where the person types a time. */
function sheet(now, choices) {
  const moments = times(now, choices)
  const blocks = [{ frame: "", title: "Snooze until", grid: "tiles" }, { repeat: "tiles", grid: "a b c" }]
  for (const [id, title, icon, none] of tiles) {
    const moment = moments[id]
    const tile = { text: id, title, detail: moment ? words(moment, now) : none, icon, look: "tile" }
    if (id === "date") tile.route = "date"
    blocks.push(tile)
  }
  return openspot.frame(blocks)
}

/** The moment that typed words name, such as `fri 3pm` or `dec 24`, read by the calculator; a day with no time takes
 * the morning. Nil when the words name no moment to come. */
function typed(text, now, choices) {
  const answer = openspot.call(["calc", "solve", text]).stdout
  const match = /^text=(\d{4})-(\d{2})-(\d{2})(?: (\d{2}):(\d{2}))?$/m.exec(answer)
  if (!match) return null
  const [hour, minute] = match[4] ? [Number(match[4]), Number(match[5])] : choices.morning
  const moment = new Date(Number(match[1]), Number(match[2]) - 1, Number(match[3]), hour, minute)
  return moment > now ? moment : null
}

/** The Pick Date page: the moment the typed words name, which Return picks, or a hint while they name none. */
function page(search, now, choices) {
  const moment = search.trim() ? typed(search, now, choices) : null
  if (!moment) {
    const title = search.trim() ? "No time to come in these words" : "Type a time"
    return openspot.frame([{ text: "hint", title, detail: "Such as fri 3pm, tomorrow 9:30 or dec 24", icon: "calendar.badge.clock" }])
  }
  const title = moment.toLocaleDateString("en-US", { weekday: "long", month: "long", day: "numeric" })
  return openspot.frame([{ text: iso(moment), title: `${title}, ${moment.getHours()}:${two(moment.getMinutes())}`, detail: "Return snoozes until then", icon: "calendar.badge.clock" }])
}

/** The form of a setting row of the snooze's Settings. */
function form(key) {
  const forms = {
    morning: ["Morning", "8:00", ["6:00", "7:00", "8:00", "9:00", "10:00"]],
    evening: ["Evening", "19:00", ["17:00", "18:00", "19:00", "20:00", "21:00"]],
    later: ["Later", "3", ["1", "2", "3", "4", "6"]],
    weekend: ["Weekend", "saturday", ["saturday", "sunday"]],
  }
  const [title, value, options] = forms[key]
  return openspot.frame([
    { frame: "", title },
    { choice: key, title, value },
    ...options.map((option) => ({ option, title: key === "later" ? `${option} hours` : option[0].toUpperCase() + option.slice(1) })),
  ])
}

/** A press of a tile, or of the typed moment, replies with its moment or `someday`; a settings row asks for its value. */
function main([id, value], env, input) {
  const now = new Date()
  if (id === "show") {
    if (openspot.value("route", input).trim() === "date") return page(openspot.value("search", input), now, choices(input))
    return sheet(now, choices(input))
  }
  if (["morning", "evening", "later", "weekend"].includes(id)) {
    const chosen = value || openspot.value(`input.${id}`, input).trim()
    if (!chosen) return form(id)
    openspot.call(["setting", "set", id, chosen])
    return ""
  }
  if (id !== "open" || !value || value === "hint" || value === "date") return ""
  const moment = value.includes("T") ? value : value === "someday" ? "someday" : iso(times(now, choices(input))[value])
  openspot.call(["spot", "reply", moment])
  return ""
}
