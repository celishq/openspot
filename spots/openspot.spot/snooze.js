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

/** The parts of the day that a picked day offers: title, icon, and its hour and minute, from the person's choices for
 * the morning and the evening. */
function dayParts(choices) {
  return [
    ["Morning", "sunrise.fill", choices.morning],
    ["Noon", "sun.max.fill", [12, 0]],
    ["Afternoon", "cup.and.saucer.fill", [15, 0]],
    ["Evening", "moon.stars.fill", choices.evening],
    ["Night", "moon.zzz.fill", [21, 0]],
  ]
}

/** The words of a day under its weekday: Today, Tomorrow, or its date. */
function dayWords(day, now) {
  const days = Math.round((at(day, 0, [0, 0]) - at(now, 0, [0, 0])) / 86400000)
  if (days === 0) return "Today"
  if (days === 1) return "Tomorrow"
  return day.toLocaleDateString("en-US", { month: "short", day: "numeric" })
}

/** The Pick Date page: the next twelve days as tiles, each with its weekday and its date. A day is offered
 * while one of its parts is still to come. */
function days(now, choices) {
  const blocks = [{ frame: "", grid: "days" }, { repeat: "days", grid: "a b c" }]
  const last = dayParts(choices).map(([, , hour]) => hour).reduce((a, b) => (a[0] * 60 + a[1] > b[0] * 60 + b[1] ? a : b))
  for (let offset = at(now, 0, last) > now ? 0 : 1, count = 0; count < 12; offset++, count++) {
    const day = at(now, offset, [0, 0])
    const route = `date/${day.getFullYear()}-${two(day.getMonth() + 1)}-${two(day.getDate())}`
    const weekday = day.toLocaleDateString("en-US", { weekday: "long" })
    blocks.push({ text: route, title: weekday, detail: dayWords(day, now), icon: "calendar", look: "tile", route, "route.title": `${weekday}, ${day.toLocaleDateString("en-US", { month: "long", day: "numeric" })}` })
  }
  return openspot.frame(blocks)
}

/** The page of one day: its parts still to come, each with the time it stands for. */
function hours(route, now, choices) {
  const [year, month, date] = route.slice("date/".length).split("-").map(Number)
  const blocks = [{ frame: "", grid: "hours" }, { repeat: "hours", grid: "a b c" }]
  for (const [title, icon, [hour, minute]] of dayParts(choices)) {
    const moment = new Date(year, month - 1, date, hour, minute)
    if (moment <= now) continue
    blocks.push({ text: iso(moment), title, detail: `${hour}:${two(minute)}`, icon, look: "tile" })
  }
  return openspot.frame(blocks)
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

/** A press of a tile, or of a part of a picked day, replies with its moment or `someday`; a settings row asks for its value. */
function main([id, value], env, input) {
  const now = new Date()
  if (id === "show") {
    const route = openspot.value("route", input).trim()
    if (route === "date") return days(now, choices(input))
    if (route.startsWith("date/")) return hours(route, now, choices(input))
    return sheet(now, choices(input))
  }
  if (["morning", "evening", "later", "weekend"].includes(id)) {
    const chosen = value || openspot.value(`input.${id}`, input).trim()
    if (!chosen) return form(id)
    openspot.call(["setting", "set", id, chosen])
    return ""
  }
  if (id !== "open" || !value || value.startsWith("date")) return ""
  const moment = value.includes("T") ? value : value === "someday" ? "someday" : iso(times(now, choices(input))[value])
  openspot.call(["spot", "reply", moment])
  return ""
}
