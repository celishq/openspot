/** The tiles of the snooze sheet in reading order: id, title and icon. */
const tiles = [
  ["hour", "In an Hour", "clock"],
  ["later", "Later Today", "cup.and.saucer"],
  ["evening", "This Evening", "moon.stars"],
  ["tomorrow", "Tomorrow", "sunrise"],
  ["weekend", "This Weekend", "sofa"],
  ["week", "Next Week", "briefcase"],
  ["month", "In a Month", "calendar"],
  ["someday", "Someday", "sparkles"],
  ["date", "Pick Date", "calendar.badge.clock"],
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
    later: minutes >= evening ? at(now, 1, choices.morning) : later,
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

/** The sheet: one view of the tiles, each with its icon, title and the time it stands for. */
function sheet(now, choices) {
  const moments = times(now, choices)
  const view = { view: "tiles" }
  tiles.forEach(([id, title, icon], index) => {
    const moment = moments[id]
    view[`tile.${index + 1}`] = [id, title, icon, moment ? words(moment, now) : ""].join("|")
  })
  return openspot.frame([{ frame: "", title: "Snooze until", grid: "tiles" }, view])
}

/** The form of a setting row of the snooze's Settings. */
function form(key) {
  const forms = {
    morning: ["Morning", "8:00", ["6:00", "7:00", "8:00", "9:00", "10:00"]],
    evening: ["Evening", "19:00", ["17:00", "18:00", "19:00", "20:00", "21:00"]],
    later: ["Later Today", "3", ["1", "2", "3", "4", "6"]],
    weekend: ["Weekend", "saturday", ["saturday", "sunday"]],
  }
  const [title, value, options] = forms[key]
  return openspot.frame([
    { frame: "", title },
    { choice: key, title, value },
    ...options.map((option) => ({ option, title: key === "later" ? `${option} hours` : option[0].toUpperCase() + option.slice(1) })),
  ])
}

/** A press of a tile replies with its moment, `someday`, or the picked date; a settings row asks for its value. */
function main([id, value], env, input) {
  if (id === "show") return sheet(new Date(), choices(input))
  if (["morning", "evening", "later", "weekend"].includes(id)) {
    const chosen = value || openspot.value(`input.${id}`, input).trim()
    if (!chosen) return form(id)
    openspot.call(["setting", "set", id, chosen])
    return ""
  }
  if (id !== "tiles" || !value) return ""
  const [tile, picked] = value.split(" ")
  const moment = tile === "date" ? picked : tile === "someday" ? "someday" : iso(times(new Date(), choices(input))[tile])
  if (!moment) return ""
  openspot.call(["spot", "reply", moment])
  return ""
}
