/** A row whose text is a colour, such as #ff3b30, rgb(255 59 48) or hsl(3, 100%, 59%), shows the colour in its preview,
 * and its ⌘K menu copies it as hex, RGBA or HSL. */

/** The colour of a text, as red, green and blue from 0 to 255 and alpha from 0 to 1, or null. */
function parse(text) {
  const value = (text || "").trim().toLowerCase()
  let hex = value.match(/^#([0-9a-f]{3}|[0-9a-f]{6}|[0-9a-f]{8})$/)
  if (hex) {
    let digits = hex[1]
    if (digits.length === 3) digits = [...digits].map((d) => d + d).join("")
    const part = (at) => parseInt(digits.slice(at, at + 2), 16)
    return { r: part(0), g: part(2), b: part(4), a: digits.length === 8 ? part(6) / 255 : 1 }
  }
  const call = value.match(/^(rgb|hsl)a?\(([^()]*)\)$/)
  if (!call) return null
  const parts = call[2].split(/[\s,/]+/).filter((p) => p !== "")
  if (parts.length < 3) return null
  const number = (p, scale) => (p.endsWith("%") ? (parseFloat(p) / 100) * scale : parseFloat(p))
  const a = parts[3] === undefined ? 1 : number(parts[3], 1)
  if (call[1] === "rgb") return { r: number(parts[0], 255), g: number(parts[1], 255), b: number(parts[2], 255), a }
  const h = parseFloat(parts[0]) / 360
  const s = number(parts[1], 1)
  const l = number(parts[2], 1)
  const channel = (t) => {
    t = (t + 1) % 1
    const q = l < 0.5 ? l * (1 + s) : l + s - l * s
    const p = 2 * l - q
    if (t < 1 / 6) return p + (q - p) * 6 * t
    if (t < 1 / 2) return q
    if (t < 2 / 3) return p + (q - p) * (2 / 3 - t) * 6
    return p
  }
  return { r: channel(h + 1 / 3) * 255, g: channel(h) * 255, b: channel(h - 1 / 3) * 255, a }
}

/** The colour as #rrggbb, with aa after it when it is not opaque. */
function hex(c) {
  const two = (n) => Math.round(Math.min(255, Math.max(0, n))).toString(16).padStart(2, "0")
  return "#" + two(c.r) + two(c.g) + two(c.b) + (c.a < 1 ? two(c.a * 255) : "")
}

/** The colour as rgba(r, g, b, a). */
function rgba(c) {
  return `rgba(${Math.round(c.r)}, ${Math.round(c.g)}, ${Math.round(c.b)}, ${+c.a.toFixed(2)})`
}

/** The colour as hsl(h, s%, l%), or hsla when it is not opaque. */
function hsl(c) {
  const r = c.r / 255
  const g = c.g / 255
  const b = c.b / 255
  const max = Math.max(r, g, b)
  const min = Math.min(r, g, b)
  const l = (max + min) / 2
  let h = 0
  let s = 0
  if (max !== min) {
    const d = max - min
    s = l > 0.5 ? d / (2 - max - min) : d / (max + min)
    h = max === r ? (g - b) / d + (g < b ? 6 : 0) : max === g ? (b - r) / d + 2 : (r - g) / d + 4
    h *= 60
  }
  const body = `${Math.round(h)}, ${Math.round(s * 100)}%, ${Math.round(l * 100)}%`
  return c.a < 1 ? `hsla(${body}, ${+c.a.toFixed(2)})` : `hsl(${body})`
}

/** Copies the row's colour in one form, and says so. */
async function copy(input, env, form) {
  const colour = parse(input["item.text"] || input["item.url"])
  if (!colour) throw new Error("This row holds no colour.")
  const text = form(colour)
  openspot.call(["clipboard", "copy"], text)
  await env.toast(`Copied ${text}.`)
}

export default {
  "item.preview"(input) {
    const colour = parse(input["item.text"] || input["item.url"])
    if (!colour) return ""
    const solid = hex({ ...colour, a: 1 })
    return [
      { frame: "", class: "flex-col gap-part" },
      { text: "hex", title: hex(colour), color: solid, class: "font-title" },
      { text: "rgba", title: rgba(colour), color: solid },
      { text: "hsl", title: hsl(colour), color: solid },
    ]
  },
  "copy-hex": (input, env) => copy(input, env, hex),
  "copy-rgba": (input, env) => copy(input, env, rgba),
  "copy-hsl": (input, env) => copy(input, env, hsl),
}
