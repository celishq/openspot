/** The addresses of the exchange-api file of rates per dollar, a public-domain file that changes once a day. */
const sources = [
  "https://cdn.jsdelivr.net/npm/@fawazahmed0/currency-api@latest/v1/currencies/usd.json",
  "https://latest.currency-api.pages.dev/v1/currencies/usd.json",
]

/** The symbol and the words of each currency the calculator reads, by its code. The trigger in spot.toml lists the
 * same symbols. */
const currencies = {
  USD: ["$", "us$", "dollar", "dollars", "bucks"],
  EUR: ["€", "euro", "euros"],
  GBP: ["£", "pound", "pounds", "sterling"],
  JPY: ["¥", "yen"],
  UAH: ["₴", "грн", "hryvnia", "hryvnias"],
  INR: ["₹", "rupee", "rupees"],
  KRW: ["₩", "won"],
  TRY: ["₺", "lira"],
  ILS: ["₪", "shekel", "shekels"],
  PLN: ["zł", "zloty"],
  BTC: ["₿", "bitcoin", "bitcoins"],
  ETH: [null, "ether", "ethereum"],
}

/** Each unit by its names, with its kind, its size in the base unit of the kind, its zero and its symbol. */
const units = (() => {
  const table = {}
  const add = (kind, size, symbol, names, zero = 0) => {
    for (const name of names) table[name] = { kind, size, zero, symbol }
  }
  add("length", 0.001, "mm", ["mm", "millimeter", "millimeters", "millimetre", "millimetres"])
  add("length", 0.01, "cm", ["cm", "centimeter", "centimeters", "centimetre", "centimetres"])
  add("length", 1, "m", ["m", "meter", "meters", "metre", "metres"])
  add("length", 1000, "km", ["km", "kilometer", "kilometers", "kilometre", "kilometres"])
  add("length", 0.0254, "in", ["in", "inch", "inches", "\""])
  add("length", 0.3048, "ft", ["ft", "foot", "feet", "'"])
  add("length", 0.9144, "yd", ["yd", "yard", "yards"])
  add("length", 1609.344, "mi", ["mi", "mile", "miles"])
  add("length", 1852, "NM", ["nmi", "nauticalmile", "nauticalmiles"])
  add("area", 1, "m²", ["m²", "sqm", "squaremeter", "squaremeters", "squaremetre", "squaremetres"])
  add("area", 1e6, "km²", ["km²", "sqkm", "squarekilometer", "squarekilometers", "squarekilometre", "squarekilometres"])
  add("area", 0.09290304, "ft²", ["ft²", "sqft", "squarefoot", "squarefeet"])
  add("area", 2589988.110336, "mi²", ["mi²", "sqmi", "squaremile", "squaremiles"])
  add("area", 10000, "ha", ["ha", "hectare", "hectares"])
  add("area", 4046.8564224, "ac", ["ac", "acre", "acres"])
  add("volume", 0.001, "mL", ["ml", "milliliter", "milliliters", "millilitre", "millilitres"])
  add("volume", 1, "L", ["l", "liter", "liters", "litre", "litres"])
  add("volume", 1000, "m³", ["m³", "cubicmeter", "cubicmeters", "cubicmetre", "cubicmetres"])
  add("volume", 3.785411784, "gal", ["gal", "gallon", "gallons"])
  add("volume", 0.946352946, "qt", ["qt", "quart", "quarts"])
  add("volume", 0.473176473, "pt", ["pt", "pint", "pints"])
  add("volume", 0.24, "cup", ["cup", "cups"])
  add("volume", 0.0295735295625, "fl oz", ["floz", "fluidounce", "fluidounces"])
  add("volume", 0.01478676478125, "tbsp", ["tbsp", "tablespoon", "tablespoons"])
  add("volume", 0.00492892159375, "tsp", ["tsp", "teaspoon", "teaspoons"])
  add("mass", 1e-6, "mg", ["mg", "milligram", "milligrams"])
  add("mass", 0.001, "g", ["g", "gram", "grams"])
  add("mass", 1, "kg", ["kg", "kilogram", "kilograms", "kilo", "kilos"])
  add("mass", 1000, "t", ["t", "tonne", "tonnes"])
  add("mass", 0.028349523125, "oz", ["oz", "ounce", "ounces"])
  add("mass", 0.45359237, "lb", ["lb", "lbs", "pound", "pounds"])
  add("mass", 6.35029318, "st", ["st", "stone", "stones"])
  add("temperature", 1, "°C", ["c", "°c", "celsius"], 273.15)
  add("temperature", 5 / 9, "°F", ["f", "°f", "fahrenheit"], 459.67 * 5 / 9)
  add("temperature", 1, "K", ["kelvin"])
  add("speed", 1, "m/s", ["m/s", "mps"])
  add("speed", 1 / 3.6, "km/h", ["km/h", "kmh", "kph"])
  add("speed", 0.44704, "mph", ["mph", "mi/h"])
  add("speed", 1852 / 3600, "kn", ["kn", "kt", "knot", "knots"])
  add("duration", 0.001, "ms", ["ms", "millisecond", "milliseconds"])
  add("duration", 1, "s", ["s", "sec", "secs", "second", "seconds"])
  add("duration", 60, "min", ["min", "mins", "minute", "minutes"])
  add("duration", 3600, "hr", ["h", "hr", "hrs", "hour", "hours"])
  add("duration", 86400, "d", ["d", "day", "days"])
  add("duration", 604800, "wk", ["wk", "week", "weeks"])
  add("storage", 0.125, "bit", ["bit", "bits"])
  add("storage", 1, "B", ["b", "byte", "bytes"])
  add("storage", 1e3, "kB", ["kb", "kilobyte", "kilobytes"])
  add("storage", 1e6, "MB", ["mb", "megabyte", "megabytes"])
  add("storage", 1e9, "GB", ["gb", "gigabyte", "gigabytes"])
  add("storage", 1e12, "TB", ["tb", "terabyte", "terabytes"])
  add("storage", 1024, "KiB", ["kib", "kibibyte", "kibibytes"])
  add("storage", 1048576, "MiB", ["mib", "mebibyte", "mebibytes"])
  add("storage", 1073741824, "GiB", ["gib", "gibibyte", "gibibytes"])
  add("energy", 1, "J", ["j", "joule", "joules"])
  add("energy", 1000, "kJ", ["kj", "kilojoule", "kilojoules"])
  add("energy", 4.184, "cal", ["cal", "calorie", "calories"])
  add("energy", 4184, "kcal", ["kcal", "kilocalorie", "kilocalories"])
  add("energy", 3.6e6, "kWh", ["kwh", "kilowatthour", "kilowatthours"])
  add("pressure", 1, "Pa", ["pa", "pascal", "pascals"])
  add("pressure", 100, "hPa", ["hpa", "hectopascal", "hectopascals"])
  add("pressure", 1000, "kPa", ["kpa", "kilopascal", "kilopascals"])
  add("pressure", 1e5, "bar", ["bar", "bars"])
  add("pressure", 6894.757293168, "psi", ["psi"])
  add("pressure", 101325, "atm", ["atm", "atmosphere", "atmospheres"])
  add("angle", 1, "°", ["°", "deg", "degree", "degrees"])
  add("angle", 180 / Math.PI, "rad", ["rad", "radian", "radians"])
  return table
})()

/** The words that join an amount to what it becomes. */
const joins = ["in", "to", "as", "into"]

/** The functions of a sum, which take degrees, and its constants. */
const functions = {
  sqrt: Math.sqrt,
  sin: (x) => Math.sin(x * Math.PI / 180),
  cos: (x) => Math.cos(x * Math.PI / 180),
  tan: (x) => Math.tan(x * Math.PI / 180),
  ln: Math.log,
  log: Math.log10,
  abs: Math.abs,
  round: Math.round,
}
const constants = { pi: [Math.PI, "π"], "π": [Math.PI, "π"], e: [Math.E, "e"] }

/** The units of a length of time that moves or counts a date. */
const steps = {
  d: "day", day: "day", days: "day", w: "week", wk: "week", week: "week", weeks: "week",
  mo: "month", month: "month", months: "month", y: "year", yr: "year", year: "year", years: "year",
  h: "hour", hr: "hour", hour: "hour", hours: "hour", min: "minute", mins: "minute", minute: "minute", minutes: "minute",
}
const months = ["jan", "feb", "mar", "apr", "may", "jun", "jul", "aug", "sep", "oct", "nov", "dec"]
const weekdays = ["sun", "mon", "tue", "wed", "thu", "fri", "sat"]
const relative = ["today", "tomorrow", "yesterday", "now", "next", "last", "in", "ago"]

/** The zone of each short name, such as pst. */
const zoneNames = {
  utc: "UTC", gmt: "UTC", pst: "America/Los_Angeles", pdt: "America/Los_Angeles", mst: "America/Denver", mdt: "America/Denver",
  cst: "America/Chicago", cdt: "America/Chicago", est: "America/New_York", edt: "America/New_York", bst: "Europe/London",
  cet: "Europe/Paris", cest: "Europe/Paris", eet: "Europe/Helsinki", eest: "Europe/Helsinki", msk: "Europe/Moscow",
  ist: "Asia/Kolkata", jst: "Asia/Tokyo", kst: "Asia/Seoul", aest: "Australia/Sydney", aedt: "Australia/Sydney",
}

/** The formatters made so far, by their options. */
const made = new Map()

/** A formatter of a kind for a locale and options, made once. */
function formatter(Kind, locale, options) {
  const key = `${Kind.name}|${locale}|${JSON.stringify(options)}`
  let kept = made.get(key)
  if (!kept) {
    if (made.size >= 64) made.clear()
    kept = new Kind(locale, options)
    made.set(key, kept)
  }
  return kept
}

/** Whether the locale writes a decimal comma. */
function hasDecimalComma(locale) {
  return formatter(Intl.NumberFormat, locale, {}).formatToParts(1.5).find((part) => part.type === "decimal")?.value === ","
}

/** The tokens of a sum: numbers, symbols and words, or null for a character that no sum has. */
function tokens(text, locale) {
  const comma = hasDecimalComma(locale)
  const chars = Array.from(text)
  const digit = (index) => index < chars.length && /[0-9]/.test(chars[index])
  const point = (char) => char === "." || (comma && char === ",")
  const symbols = { "+": "+", "-": "-", "−": "-", "*": "*", "×": "*", "·": "*", "/": "/", "÷": "/", "^": "^", "%": "%", "(": "(", ")": ")" }
  const found = []
  let index = 0
  while (index < chars.length) {
    const char = chars[index]
    if (/\s/.test(char)) {
      index += 1
    } else if (/[0-9]/.test(char) || (point(char) && digit(index + 1))) {
      let number = ""
      let hasPoint = false
      while (index < chars.length) {
        const next = chars[index]
        if (digit(index)) {
          number += next
        } else if (point(next) && !hasPoint && digit(index + 1)) {
          number += "."
          hasPoint = true
        } else if (next === "," && !comma && !hasPoint && digit(index + 1) && digit(index + 2) && digit(index + 3) && !digit(index + 4)) {
          index += 1
          continue
        } else if (next === "," && !comma) {
          return null
        } else {
          break
        }
        index += 1
      }
      if (chars[index] === "e" || chars[index] === "E") {
        let end = index + 1
        if (chars[end] === "+" || chars[end] === "-") end += 1
        if (digit(end)) {
          number += chars.slice(index, end).join("")
          index = end
          while (digit(index)) number += chars[index++]
        }
      }
      found.push({ number: Number(number) })
    } else if (symbols[char]) {
      found.push({ symbol: symbols[char] })
      index += 1
    } else if (/\p{L}/u.test(char)) {
      let word = ""
      while (index < chars.length && /\p{L}/u.test(chars[index])) word += chars[index++]
      found.push({ word: word.toLowerCase() })
    } else {
      return null
    }
  }
  return found
}

/** A number as people typed it, in the way of the locale, with no grouping. */
function typed(number, locale) {
  return formatter(Intl.NumberFormat, locale, { useGrouping: false, maximumSignificantDigits: 15 }).format(number)
}

/** A sum read from the text: its value, how it reads, and whether it holds no operation. */
function expression(text, locale) {
  const list = tokens(text, locale)
  if (!list || list.length === 0) return null
  let index = 0
  let operations = 0
  const next = () => list[index]
  const plain = (term) => term.percent ? term.value / 100 : term.value
  const isSymbol = (token, symbol) => token !== undefined && token.symbol === symbol
  const followsImplicitly = (token) => token !== undefined && (token.symbol === "(" || (token.word !== undefined && (functions[token.word] || constants[token.word])))
  const startsValue = (token) => token !== undefined && (token.number !== undefined || followsImplicitly(token))
  const marks = { 0: "⁰", 1: "¹", 2: "²", 3: "³", 4: "⁴", 5: "⁵", 6: "⁶", 7: "⁷", 8: "⁸", 9: "⁹", "−": "⁻" }
  const raised = (text) => Array.from(text).every((char) => marks[char]) ? Array.from(text).map((char) => marks[char]).join("") : `^${text}`

  const additive = () => {
    let left = multiplicative()
    if (!left) return null
    while (isSymbol(next(), "+") || isSymbol(next(), "-")) {
      const symbol = next().symbol
      index += 1
      const right = multiplicative()
      if (!right) return null
      operations += 1
      const sign = symbol === "+" ? 1 : -1
      const value = right.percent && !left.percent ? left.value * (1 + sign * right.value / 100) : plain(left) + sign * plain(right)
      left = { value, text: `${left.text} ${symbol === "+" ? "+" : "−"} ${right.text}` }
    }
    return left
  }

  const multiplicative = () => {
    let left = unary()
    if (!left) return null
    while (true) {
      const token = next()
      let symbol
      if (isSymbol(token, "*") || (token && token.word === "x")) symbol = "×"
      else if (isSymbol(token, "/")) symbol = "÷"
      else if (isSymbol(token, "%")) symbol = "mod"
      else if (token && token.word === "of" && left.percent) symbol = "of"
      else if (followsImplicitly(token)) symbol = ""
      else return left
      if (symbol) index += 1
      const right = unary()
      if (!right) return null
      operations += 1
      const value = symbol === "÷" ? plain(left) / plain(right)
        : symbol === "mod" ? plain(left) % plain(right)
        : symbol === "of" ? left.value / 100 * plain(right)
        : plain(left) * plain(right)
      const text = symbol === "mod" ? `${left.text} mod ${right.text}` : `${left.text} ${symbol || "×"} ${right.text}`
      left = { value, text }
    }
  }

  const unary = () => {
    const token = next()
    if (!isSymbol(token, "-") && !isSymbol(token, "+")) return power()
    index += 1
    const term = unary()
    if (!term) return null
    return token.symbol === "-" ? { value: -term.value, text: `−${term.text}`, percent: term.percent } : term
  }

  const power = () => {
    const base = postfix()
    if (!base) return null
    if (!isSymbol(next(), "^")) return base
    index += 1
    const exponent = unary()
    if (!exponent) return null
    operations += 1
    return { value: Math.pow(plain(base), plain(exponent)), text: `${base.text}${raised(exponent.text)}` }
  }

  const postfix = () => {
    const term = primary()
    if (!term) return null
    if (isSymbol(next(), "%") && !startsValue(list[index + 1])) {
      index += 1
      return { value: term.value, text: `${term.text}%`, percent: true }
    }
    return term
  }

  const primary = () => {
    const token = next()
    if (token === undefined) return null
    if (token.number !== undefined) {
      index += 1
      return { value: token.number, text: typed(token.number, locale) }
    }
    if (token.symbol === "(") {
      index += 1
      const inner = additive()
      if (!inner || !isSymbol(next(), ")")) return null
      index += 1
      return { value: plain(inner), text: `(${inner.text})` }
    }
    if (token.word === undefined) return null
    if (constants[token.word]) {
      index += 1
      operations += 1
      return { value: constants[token.word][0], text: constants[token.word][1] }
    }
    const fn = functions[token.word]
    if (!fn) return null
    index += 1
    const argument = unary()
    if (!argument) return null
    operations += 1
    const text = argument.text.startsWith("(") ? argument.text : `(${argument.text})`
    return { value: fn(plain(argument)), text: `${token.word}${text}` }
  }

  const term = additive()
  if (!term || index !== list.length) return null
  const value = term.percent ? term.value / 100 : term.value
  if (!Number.isFinite(value)) return null
  return { value, detail: term.text, isPlain: operations === 0 }
}

/** A value with at most a count of significant digits, as a machine reads it. */
function plainValue(value, digits) {
  if (Math.abs(value) >= 1e15) return value.toExponential(digits - 1).replace(/\.?0+e/, "e")
  return formatter(Intl.NumberFormat, "en-US", { useGrouping: false, maximumSignificantDigits: digits }).format(value)
}

/** A value as people of the locale write it, in a scientific form when it is very large or very small. */
function written(value, locale) {
  const scientific = Math.abs(value) >= 1e15 || (value !== 0 && Math.abs(value) < 1e-9)
  return formatter(Intl.NumberFormat, locale, { maximumSignificantDigits: 15, ...(scientific ? { notation: "scientific" } : {}) }).format(value)
}

/** The ways to read the text as an amount of something, the last join first, then the whole text. */
function splits(text, locale) {
  const words = text.split(/\s+/).filter(Boolean)
  const found = []
  for (let index = words.length - 2; index > 0; index -= 1) {
    if (!joins.includes(words[index].toLowerCase())) continue
    const split = conversion(words.slice(0, index).join(" "), words.slice(index + 1).join(" "), locale)
    if (split) found.push(split)
  }
  const whole = conversion(text, null, locale)
  if (whole) found.push(whole)
  return found
}

/** An amount and the name of what it counts, such as 5 km, $15 or (2+3) kg. */
function conversion(quantity, to, locale) {
  const last = Math.max(...Array.from(quantity).map((char, index) => /[0-9)]/.test(char) ? index : -1))
  if (last < 0) return null
  let amountText
  let from
  const name = quantity.slice(last + 1).trim()
  if (name) {
    amountText = quantity.slice(0, last + 1)
    from = name
  } else {
    const start = Array.from(quantity).findIndex((char) => /[0-9(.\-+]/.test(char))
    const prefix = quantity.slice(0, Math.max(start, 0)).trim()
    if (!prefix || /[\p{L}\p{N}]/u.test(prefix)) return null
    amountText = quantity.slice(start)
    from = prefix
  }
  const amount = expression(amountText, locale)
  return amount ? { amount, from, to } : null
}

/** The unit of a name, such as km or °F. */
function unit(name) {
  return units[name.toLowerCase().replace(/ /g, "")] || null
}

/** The code of a currency the text names, such as EUR for € or euros, or a short code such as CHF. */
function currencyCode(name) {
  const lower = name.toLowerCase()
  for (const [code, [symbol, ...words]] of Object.entries(currencies)) {
    if (lower === symbol || words.includes(lower)) return code
  }
  if (lower.length < 2 || lower.length > 5 || !/^[a-z0-9]+$/.test(lower) || unit(lower)) return null
  return lower.toUpperCase()
}

/** Whether a code is a currency of a country. */
function isFiat(code) {
  return Intl.supportedValuesOf("currency").includes(code)
}

/** Whether a code is surely a currency, and not a short word that may mean something else. */
function isUnambiguous(code) {
  return isFiat(code) || code === "BTC" || code === "ETH"
}

/** The rates of the exchange-api file: its day and the rate of each currency per dollar, or null for a cut file. */
function ratesOf(text) {
  let file
  try { file = JSON.parse(text) } catch { return null }
  if (!file || typeof file.date !== "string" || !file.usd || typeof file.usd !== "object") return null
  const perDollar = {}
  for (const [code, rate] of Object.entries(file.usd)) if (typeof rate === "number" && rate > 0) perDollar[code.toUpperCase()] = rate
  if (Object.keys(perDollar).length === 0) return null
  perDollar.USD = 1
  return { day: file.date, perDollar, count: Object.keys(perDollar).length }
}

/** Whether new rates take the place of the kept ones: as new and nearly as full. */
function replaces(fresh, kept) {
  return fresh.day >= kept.day && fresh.count * 2 >= kept.count
}

/** The answer in units of another of the same kind. */
function unitAnswer(split, locale) {
  const from = unit(split.from)
  const to = unit(split.to)
  if (!from || !to || from.kind !== to.kind) return null
  const value = ((split.amount.value * from.size + from.zero) - to.zero) / to.size
  if (!Number.isFinite(value)) return null
  const number = formatter(Intl.NumberFormat, locale, { useGrouping: false, maximumSignificantDigits: 6 }).format(value)
  const title = to.kind === "temperature" ? `${number}${to.symbol}` : `${number} ${to.symbol}`
  return { item: plainValue(value, 6), title, detail: `${split.amount.detail} ${split.from} in ${split.to}`, unit: to.symbol }
}

/** A money value as people of the locale write it, with the calculator's symbol where the locale shows the code. */
function money(value, code, locale) {
  const fiat = isFiat(code)
  const options = { style: "currency", currency: code, ...(fiat ? {} : { minimumFractionDigits: 0, maximumFractionDigits: 8 }) }
  let parts
  let digits
  try {
    const format = formatter(Intl.NumberFormat, locale, options)
    parts = format.formatToParts(value)
    digits = format.resolvedOptions().maximumFractionDigits
  } catch {
    return { title: `${formatter(Intl.NumberFormat, locale, { maximumFractionDigits: 8 }).format(value)} ${code}`, symbol: code, digits: 8 }
  }
  const own = currencies[code] && currencies[code][0]
  const shown = parts.find((part) => part.type === "currency")?.value
  if (own && shown === code) {
    const tight = !formatter(Intl.NumberFormat, locale, { style: "currency", currency: "USD" }).formatToParts(1).some((part, index, all) => part.type === "literal" && (all[index - 1]?.type === "currency" || all[index + 1]?.type === "currency"))
    parts = parts
      .map((part) => part.type === "currency" ? { ...part, value: own } : part)
      .filter((part, index, all) => !(tight && part.type === "literal" && /^\s+$/.test(part.value) && (all[index - 1]?.type === "currency" || all[index + 1]?.type === "currency")))
  }
  return { title: parts.map((part) => part.value).join(""), symbol: own && shown === code ? own : shown || code, digits }
}

/** The answer of an amount in another currency, a status when the rates are missing, or null when it names none. */
function currencyAnswer(split, context, asked) {
  const from = currencyCode(split.from)
  const to = split.to ? currencyCode(split.to) : context.currency
  if (!from || !to || from === to) return null
  if (!(isUnambiguous(from) || (split.to && isUnambiguous(to)))) return null
  const kept = asked()
  if (!kept.rates) return isUnambiguous(from) && isUnambiguous(to) ? { status: kept.failure } : null
  const fromRate = kept.rates.perDollar[from]
  const toRate = kept.rates.perDollar[to]
  if (!fromRate || !toRate) return null
  const value = split.amount.value * toRate / fromRate
  const shown = money(value, to, context.locale)
  const age = daysBetween(dayOf(kept.rates.day), fields(context.now, context.timeZone))
  const old = age >= 3 ? `, ${formatter(Intl.NumberFormat, context.locale, { style: "unit", unit: "day", unitDisplay: "long" }).format(age)} old` : ""
  return {
    item: formatter(Intl.NumberFormat, "en-US", { useGrouping: false, maximumFractionDigits: shown.digits }).format(value),
    title: shown.title,
    detail: `${split.amount.detail} ${from} in ${to}`,
    unit: shown.symbol,
    rates: `${ratesDay(kept.rates.day, context)}${old}`,
    tone: old ? "warn" : undefined,
  }
}

/** The day of the rates, such as Nov 10, with its year when it is not this year's. */
function ratesDay(day, context) {
  const parts = dayOf(day)
  if (!parts) return day
  const thisYear = fields(context.now, context.timeZone).year === parts.year
  return formatter(Intl.DateTimeFormat, context.locale, { month: "short", day: "numeric", ...(thisYear ? {} : { year: "numeric" }), timeZone: "UTC" })
    .format(new Date(Date.UTC(parts.year, parts.month - 1, parts.day)))
}

/** The year, month and day of a yyyy-mm-dd text. */
function dayOf(text) {
  const match = /^(\d{4})-(\d{1,2})-(\d{1,2})$/.exec(text)
  return match ? { year: Number(match[1]), month: Number(match[2]), day: Number(match[3]), hour: 0, minute: 0 } : null
}

/** The wall clock of a moment in a zone: year, month, day, hour, minute and weekday. */
function fields(date, zone) {
  const parts = formatter(Intl.DateTimeFormat, "en-US", {
    timeZone: zone, hourCycle: "h23", year: "numeric", month: "numeric", day: "numeric", hour: "numeric", minute: "numeric", second: "numeric", weekday: "short",
  }).formatToParts(date)
  const value = (type) => parts.find((part) => part.type === type)?.value
  return {
    year: Number(value("year")), month: Number(value("month")), day: Number(value("day")),
    hour: Number(value("hour")) % 24, minute: Number(value("minute")), second: Number(value("second")),
    weekday: weekdays.indexOf(value("weekday").toLowerCase()),
  }
}

/** The moment of a wall clock in a zone. */
function moment(wall, zone) {
  const guess = Date.UTC(wall.year, wall.month - 1, wall.day, wall.hour || 0, wall.minute || 0)
  const offset = (at) => {
    const seen = fields(new Date(at), zone)
    return Date.UTC(seen.year, seen.month - 1, seen.day, seen.hour, seen.minute, seen.second) - at
  }
  const first = guess - offset(guess)
  return new Date(guess - offset(first))
}

/** The whole days from one wall day to another. */
function daysBetween(from, to) {
  if (!from || !to) return null
  return Math.round((Date.UTC(to.year, to.month - 1, to.day) - Date.UTC(from.year, from.month - 1, from.day)) / 86400000)
}

/** A wall clock moved by a count of a step, keeping the time of day for days and the last day of a short month. */
function moved(wall, step, count) {
  const next = { ...wall }
  if (step === "day" || step === "week") {
    const at = new Date(Date.UTC(wall.year, wall.month - 1, wall.day + count * (step === "week" ? 7 : 1)))
    return { ...next, year: at.getUTCFullYear(), month: at.getUTCMonth() + 1, day: at.getUTCDate() }
  }
  const total = wall.year * 12 + (wall.month - 1) + count * (step === "year" ? 12 : 1)
  next.year = Math.floor(total / 12)
  next.month = total % 12 + 1
  next.day = Math.min(wall.day, new Date(Date.UTC(next.year, next.month, 0)).getUTCDate())
  return next
}

/** The date a text names, such as today, 25 dec, 2026-12-25 or next friday, and whether it names a time. */
function dateOf(text, context) {
  const zone = context.timeZone
  const now = fields(context.now, zone)
  const today = { ...now, hour: 0, minute: 0 }
  const at = (wall, hasTime) => ({ wall, hasTime, date: moment(wall, zone) })
  const value = text.trim()
  const time = String.raw`(?:(\d{1,2}):(\d{2})\s*(am|pm)?|(\d{1,2})\s*(am|pm)|(noon)|(midnight))`
  const clock = (match, from) => {
    if (match[from] !== undefined) return twelve(Number(match[from]), Number(match[from + 1]), match[from + 2])
    if (match[from + 3] !== undefined) return twelve(Number(match[from + 3]), 0, match[from + 4])
    if (match[from + 5] !== undefined) return { hour: 12, minute: 0 }
    if (match[from + 6] !== undefined) return { hour: 0, minute: 0 }
    return null
  }
  const twelve = (hour, minute, half) => {
    if (half === "pm" && hour < 12) hour += 12
    if (half === "am" && hour === 12) hour = 0
    return hour < 24 && minute < 60 ? { hour, minute } : undefined
  }
  const withTime = (day, match, from) => {
    if (!day) return null
    const found = clock(match, from)
    if (found === undefined) return null
    return found ? at({ ...day, ...found }, true) : at(day, false)
  }
  const valid = (year, month, day) => month >= 1 && month <= 12 && day >= 1 && day <= new Date(Date.UTC(year, month, 0)).getUTCDate()
  const ahead = (month, day) => {
    let year = now.year
    if (!valid(year, month, day)) return null
    if (daysBetween(today, { year, month, day }) < 0) year += 1
    return valid(year, month, day) ? { year, month, day, hour: 0, minute: 0 } : null
  }
  const named = (year, month, day) => year === undefined ? ahead(month, day) : valid(Number(year), month, day) ? { year: Number(year), month, day, hour: 0, minute: 0 } : null
  const monthOf = (word) => months.indexOf(word.slice(0, 3)) + 1
  const monthWords = "(jan(?:uary)?|feb(?:ruary)?|mar(?:ch)?|apr(?:il)?|may|jun(?:e)?|jul(?:y)?|aug(?:ust)?|sep(?:t(?:ember)?)?|oct(?:ober)?|nov(?:ember)?|dec(?:ember)?)"
  const dayWords = "(sun(?:day)?|mon(?:day)?|tue(?:s(?:day)?)?|wed(?:nesday)?|thu(?:r(?:s(?:day)?)?)?|fri(?:day)?|sat(?:urday)?)"
  const tail = String.raw`(?:,?\s+(?:at\s+)?${time})?`
  let match
  if (value === "now") return at(now, true)
  if (value === "today") return at(today, false)
  if (value === "tomorrow") return at(moved(today, "day", 1), false)
  if (value === "yesterday") return at(moved(today, "day", -1), false)
  if ((match = new RegExp(String.raw`^(today|tomorrow|yesterday)\s+(?:at\s+)?${time}$`).exec(value))) {
    return withTime(moved(today, "day", { today: 0, tomorrow: 1, yesterday: -1 }[match[1]]), match, 2)
  }
  if ((match = new RegExp(String.raw`^(\d{4})-(\d{1,2})-(\d{1,2})(?:[\st]+${time})?$`).exec(value))) {
    return withTime(named(match[1], Number(match[2]), Number(match[3])), match, 4)
  }
  if ((match = new RegExp(String.raw`^(\d{1,2})\.(\d{1,2})\.(\d{4}|\d{2})${tail}$`).exec(value))) {
    const year = match[3].length === 2 ? `20${match[3]}` : match[3]
    return withTime(named(year, Number(match[2]), Number(match[1])), match, 4)
  }
  if ((match = new RegExp(String.raw`^(\d{1,2})(?:st|nd|rd|th)?\s+${monthWords}\.?(?:,?\s+(\d{4}))?${tail}$`).exec(value))) {
    return withTime(named(match[3], monthOf(match[2]), Number(match[1])), match, 4)
  }
  if ((match = new RegExp(String.raw`^${monthWords}\.?\s+(\d{1,2})(?:st|nd|rd|th)?(?:,?\s+(\d{4}))?${tail}$`).exec(value))) {
    return withTime(named(match[3], monthOf(match[1]), Number(match[2])), match, 4)
  }
  if ((match = new RegExp(String.raw`^(?:(next|last|this)\s+)?${dayWords}$`).exec(value))) {
    const target = weekdays.indexOf(match[2].slice(0, 3))
    if (match[1] === "last") {
      const back = (now.weekday - target + 7) % 7 || 7
      return at(moved(today, "day", -back), false)
    }
    const forward = (target - now.weekday + 7) % 7 || 7
    const monday = (weekday) => (weekday + 6) % 7
    const later = match[1] === "next" && monday(now.weekday) + forward <= 6 ? forward + 7 : forward
    return at(moved(today, "day", later), false)
  }
  if ((match = /^(next|last)\s+(week|month|year)$/.exec(value))) {
    return at(moved(today, match[2], match[1] === "next" ? 1 : -1), false)
  }
  if ((match = /^in\s+(\d+)\s*([a-z]+)$/.exec(value)) || (match = /^(\d+)\s*([a-z]+)\s+ago$/.exec(value))) {
    const step = steps[match[2]]
    if (!step) return null
    const count = Number(match[1]) * (value.endsWith("ago") ? -1 : 1)
    if (step === "hour" || step === "minute") return { date: new Date(context.now.getTime() + count * (step === "hour" ? 3600000 : 60000)), hasTime: true }
    return at(moved(today, step, count), false)
  }
  if ((match = new RegExp(String.raw`^${time}$`).exec(value))) {
    return withTime(today, match, 1)
  }
  return null
}

/** The formats of dates for a locale and the zone of the clock. */
function dateFormats(context) {
  const day = (date, hasTime, zone = context.timeZone) => formatter(Intl.DateTimeFormat, context.locale, {
    weekday: "short", month: "short", day: "numeric", year: "numeric", ...(hasTime ? { hour: "numeric", minute: "2-digit" } : {}), timeZone: zone,
  }).format(date)
  const time = (date, zone) => formatter(Intl.DateTimeFormat, context.locale, { weekday: "short", hour: "numeric", minute: "2-digit", timeZone: zone })
  const value = (date, hasTime, zone = context.timeZone) => {
    const wall = fields(date, zone)
    const two = (number) => String(number).padStart(2, "0")
    return `${wall.year}-${two(wall.month)}-${two(wall.day)}${hasTime ? ` ${two(wall.hour)}:${two(wall.minute)}` : ""}`
  }
  return { day, time, value }
}

/** The answer of a date moved by lengths, such as today + 3 weeks. */
function movedAnswer(text, context, format) {
  const match = /^(.+?)\s*((?:[+-]\s*\d+\s*[a-z]+\s*)+)$/.exec(text)
  if (!match) return null
  const start = dateOf(match[1], context)
  if (!start) return null
  let date = start.date
  let hasTime = start.hasTime
  for (const length of match[2].matchAll(/([+-])\s*(\d+)\s*([a-z]+)/g)) {
    const step = steps[length[3]]
    if (!step) return null
    const count = Number(length[2]) * (length[1] === "-" ? -1 : 1)
    if (step === "hour" || step === "minute") {
      date = new Date(date.getTime() + count * (step === "hour" ? 3600000 : 60000))
      hasTime = true
    } else {
      date = moment(moved(fields(date, context.timeZone), step, count), context.timeZone)
    }
  }
  const lengths = match[2].trim().replace(/([+-])\s*/g, "$1 ")
  return { item: format.value(date, hasTime), title: format.day(date, hasTime), detail: `${format.day(start.date, start.hasTime)} ${lengths}` }
}

/** The answer of a count of days, weeks, months, years, hours or minutes between two dates. */
function countAnswer(text, context, format) {
  let step
  let from
  let to
  let match
  const now = { date: context.now, hasTime: true }
  if ((match = /^(days|weeks|months|years|hours|minutes)\s+(until|till|to|before|since|from|after)\s+(.+)$/.exec(text))) {
    step = steps[match[1]]
    let date = dateOf(match[3], context)
    if (!date) return null
    const since = ["since", "from", "after"].includes(match[2])
    if (since && !/\d{4}/.test(match[3]) && date.date > context.now) {
      const back = daysBetween(fields(date.date, context.timeZone), fields(context.now, context.timeZone)) === 0 ? "day" : "year"
      let wall = fields(date.date, context.timeZone)
      while (moment(wall, context.timeZone) > context.now) wall = moved(wall, back, -1)
      date = { date: moment(wall, context.timeZone), hasTime: date.hasTime }
    }
    ;[from, to] = since ? [date, now] : [now, date]
  } else if ((match = /^(.+?)\s+-\s+(.+)$/.exec(text))) {
    const later = dateOf(match[1], context)
    const earlier = dateOf(match[2], context)
    if (!later || !earlier) return null
    step = "day"
    ;[from, to] = [earlier, later]
  } else {
    return null
  }
  const timed = step === "hour" || step === "minute"
  const a = fields(from.date, context.timeZone)
  const b = fields(to.date, context.timeZone)
  const days = daysBetween(a, b)
  const toward = (number) => number < 0 ? Math.ceil(number) : Math.floor(number)
  const monthsBetween = () => {
    let count = (b.year - a.year) * 12 + (b.month - a.month)
    if (count > 0 && b.day < a.day) count -= 1
    if (count < 0 && b.day > a.day) count += 1
    return count
  }
  const count = step === "hour" ? toward((to.date - from.date) / 3600000)
    : step === "minute" ? toward((to.date - from.date) / 60000)
    : step === "week" ? toward(days / 7)
    : step === "month" ? monthsBetween()
    : step === "year" ? toward(monthsBetween() / 12)
    : days
  const detail = `${format.day(from.date, from.hasTime && timed)} to ${format.day(to.date, to.hasTime && timed)}`
  const title = formatter(Intl.NumberFormat, context.locale, { style: "unit", unit: step, unitDisplay: "long" }).format(count)
  const number = formatter(Intl.NumberFormat, context.locale, {}).format(count)
  const words = title.replace(number, "").trim()
  return { item: String(count), title, detail, unit: words || undefined }
}

/** The zone a name gives, such as tokyo, new york or pst. */
function zoneOf(name) {
  const key = name.trim().toLowerCase()
  if (zoneNames[key]) return zoneNames[key]
  return Intl.supportedValuesOf("timeZone").find((zone) => zone.split("/").pop().replace(/_/g, " ").toLowerCase() === key) || null
}

/** The answer of a time in another zone, such as 3pm tokyo in berlin. */
function zonedAnswer(text, context, format) {
  const joins = [...text.matchAll(/\s+in\s+/g)].reverse()
  for (const join of joins) {
    const target = zoneOf(text.slice(join.index + join[0].length))
    if (!target) continue
    const source = text.slice(0, join.index)
    let date
    let zone
    if (["now", "time", "the time"].includes(source)) {
      date = context.now
      zone = context.timeZone
    } else {
      const match = /^(?:(\d{1,2})(?::(\d{2}))?\s*(am|pm)?|(noon)|(midnight))\s*(.*)$/.exec(source)
      if (!match) continue
      let hour = match[1] !== undefined ? Number(match[1]) : match[4] ? 12 : 0
      const minute = match[2] !== undefined ? Number(match[2]) : 0
      if (match[3] === "pm" && hour < 12) hour += 12
      if (match[3] === "am" && hour === 12) hour = 0
      zone = match[6] ? zoneOf(match[6]) : context.timeZone
      if (hour >= 24 || minute >= 60 || !zone) continue
      date = moment({ ...fields(context.now, zone), hour, minute }, zone)
    }
    const shown = format.time(date, target)
    const title = shown.format(date)
    const half = shown.formatToParts(date).find((part) => part.type === "dayPeriod")?.value
    const place = zone.split("/").pop().replace(/_/g, " ")
    return { item: format.value(date, true, target), title, detail: `${format.time(date, zone).format(date)} · ${place}`, unit: half }
  }
  return null
}

/** The answer of a date alone, such as 25 dec or next friday. */
function aloneAnswer(text, context, format) {
  const words = text.split(" ")
  if (!/\d/.test(text) && !words.some((word) => relative.includes(word))) return null
  if (/^\d{1,2}(:\d{2})?\s*(am|pm)?$/.test(text)) return null
  const date = dateOf(text, context)
  if (!date) return null
  return { item: format.value(date.date, date.hasTime), title: format.day(date.date, date.hasTime), detail: text }
}

/** The answer of a date: a date moved, a count, a time in another zone, or a date alone. */
function dateAnswer(text, context) {
  const lower = text.toLowerCase().trim()
  const format = dateFormats(context)
  return movedAnswer(lower, context, format) || countAnswer(lower, context, format) || zonedAnswer(lower, context, format) || aloneAnswer(lower, context, format)
}

/** The answer to a text: a conversion, a sum or a date, a status of missing rates, or null. The context holds the
 * locale, the currency of the Mac, the zone of its clock, the moment now, and a function that gives the rates. */
function solve(text, context) {
  const trimmed = text.trim()
  let asked
  const rates = () => asked ??= context.rates()
  for (const split of splits(trimmed, context.locale)) {
    if (split.to) {
      const answer = unitAnswer(split, context.locale)
      if (answer) return answer
    }
    const answer = currencyAnswer(split, context, rates)
    if (answer) return answer
  }
  if (!/^\d{4}-\d{1,2}-\d{1,2}(\s|$)/.test(trimmed)) {
    const sum = expression(trimmed, context.locale)
    if (sum && !sum.isPlain) return { item: plainValue(sum.value, 15), title: written(sum.value, context.locale), detail: sum.detail }
  }
  return dateAnswer(trimmed, context)
}

/** The rates kept in the cache, or why there are none: loading while the filler runs, or its last failure. */
function keptRates(env) {
  const kept = env.cache.get("rates")
  const rates = kept && ratesOf(kept.value)
  if (rates) return { rates }
  const failed = env.cache.get("rates-failure")
  return { failure: failed && failed.age < 60 ? failed.value : "loading" }
}

/** The row that says why a currency has no rates, by the status of the rates. */
const noRates = {
  loading: { item: "loading", title: "Getting exchange rates", icon: "arrow.triangle.2.circlepath" },
  offline: { item: "offline", title: "No exchange rates", detail: "Openspot cannot get exchange rates. Connect to the internet, then type again.", icon: "wifi.slash" },
  unavailable: { item: "offline", title: "No exchange rates", detail: "The source of the rates does not answer. Sums, units and dates still work. Try again later.", icon: "exclamationmark.triangle" },
}

/** The card of an answer: the sum as it was read, faint, over the big answer with its unit faint, which fills the rest
 * of the card. The sum names the day of old rates. A pick copies the plain value. */
function card(solved) {
  return [
    { frame: "", value: "answer" },
    { text: "sum", class: "large:flex text-secondary", title: solved.tone ? `${solved.detail} · rates of ${solved.rates}` : solved.detail },
    { number: "answer", class: "large:flex", grow: true, value: solved.item, display: solved.title, unit: solved.unit },
    { button: "press", title: "Copy", scope: "spot" },
  ]
}

export default {
  /** The card of the answer of a sum, a conversion or a date, in the turn of the key. A currency reads the rates that
   * the cache keeps, and shows Getting exchange rates until the filler brings them. */
  search({ text }, env) {
    if (!text) return ""
    const solved = solve(text, { locale: env.locale, currency: env.currency, timeZone: Intl.DateTimeFormat().resolvedOptions().timeZone, now: new Date(), rates: () => keptRates(env) })
    if (!solved) return ""
    if (solved.status) return [noRates[solved.status]]
    return card(solved)
  },
  /** Fetches the rates from the first source that answers with a good file, and keeps them unless the kept ones are
   * newer or far fuller. A failure is kept for a minute, so that the reads in it fetch nothing. */
  async "cache.rates"(_, env) {
    const failed = env.cache.get("rates-failure")
    if (failed && failed.age < 60) return
    let cause = "unavailable"
    for (const source of sources) {
      try {
        const answer = await env.fetch(source)
        if (!answer.ok) continue
        const text = await answer.text()
        const fresh = ratesOf(text)
        if (!fresh) continue
        const kept = env.cache.get("rates")
        const old = kept && ratesOf(kept.value)
        env.cache.set("rates", !old || replaces(fresh, old) ? text : kept.value)
        return
      } catch (error) {
        if (error.cause === "offline") cause = "offline"
      }
    }
    env.cache.set("rates-failure", cause)
  },
  /** A pick copies the plain value. */
  async press({ item }, env) {
    if (!["offline", "loading"].includes(item) && openspot.call(["clipboard", "copy"], item).code === 0) await env.toast(`Copied ${item}`)
  },
}
