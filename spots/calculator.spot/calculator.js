
/** The item that says why a currency has no rates, by the status that `openspot calc solve` prints. */
const noRates = {
  "status=offline": "detail=Openspot cannot get exchange rates. Connect to the internet, then type again.\nicon=wifi.slash\n",
  "status=unavailable": "detail=The source of the rates does not answer. Sums, units and dates still work. Try again later.\nicon=exclamationmark.triangle\n",
}

/** The fields of the answer that `openspot calc solve` prints, by key. */
function fields(text) {
  return Object.fromEntries(text.trim().split("\n").map((line) => [line.slice(0, line.indexOf("=")), line.slice(line.indexOf("=") + 1)]))
}

/** The card of an answer: the big answer with its unit faint, over the sum as it was read, faint. The sum names the day
 * of old rates. A pick copies the plain value. */
function card(solved) {
  return openspot.frame([
    { frame: "" },
    { number: "answer", class: "large:flex", value: solved.item, display: solved.title, unit: solved.unit, title: solved.tone ? `${solved.detail} · rates of ${solved.rates}` : solved.detail },
    { button: "press", title: "Copy", scope: "spot" },
  ])
}

export default {
  /** The card of the answer of a sum, a conversion or a date for a read. It solves with `openspot.call`, which answers
   * at once, so the row shows in the turn of the key, where `env.calc.solve` would answer after it. */
  search({ text }) {
    if (!text) return ""
    const answer = openspot.call(["calc", "solve", text]).stdout
    const why = noRates[answer.trim()]
    if (why) return "item=offline\ntitle=No exchange rates\n" + why
    const solved = fields(answer)
    return solved.item ? card(solved) : answer
  },
  /** A pick copies the plain value. */
  async press({ item }, env) {
    if (item !== "offline" && openspot.call(["clipboard", "copy"], item).code === 0) await env.toast(`Copied ${item}`)
  },
}
