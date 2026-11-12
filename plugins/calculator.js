// title=Calculator
// icon=equal.square
// detail=Sums, units, currencies and dates
// mode=inline
// answers=^\s*([-+(.$€£¥₴₿₹₩₺₪π0-9]|(?i:the|today|tomorrow|yesterday|now|time|next|last|in|days|weeks|months|years|hours|minutes|sqrt|sin|cos|tan|ln|log|abs|round|pi|noon|midnight)\b)
// uses=clipboard

/** The row that says why a currency has no rates, by the status that `openspot calc solve` prints. */
const noRates = {
  "status=offline": "detail=Openspot cannot get exchange rates. Connect to the internet, then type again.\nicon=wifi.slash\n",
  "status=unavailable": "detail=The source of the rates does not answer. Sums, units and dates still work. Try again later.\nicon=exclamationmark.triangle\n",
}

/** The fields of the row that `openspot calc solve` prints, by key. */
function fields(text) {
  return Object.fromEntries(text.trim().split("\n").map((line) => [line.slice(0, line.indexOf("=")), line.slice(line.indexOf("=") + 1)]))
}

/** The card of an answer: the sum as it was read over the big answer, whose pick sends the plain value. */
function card(row) {
  return openspot.frame([
    { "grid.large": ["sum sum sum sum", "answer answer answer answer", "answer answer answer answer"], main: "answer" },
    { number: "sum", value: row.detail },
    { number: "answer", value: row.row, display: row.title },
  ])
}

/** The card of the answer of a sum, a conversion or a date for a read, or the row of an answer from old rates, which warns.
 * A pick copies the plain value. */
function main([id, text]) {
  if (id === "open") {
    if (text === "offline" || openspot.call(["clipboard", "copy"], text).code !== 0) return ""
    return openspot.frame({ toast: `Copied ${text}` })
  }
  if (!text) return ""
  const answer = openspot.call(["calc", "solve", text]).stdout
  const why = noRates[answer.trim()]
  if (why) return "row=offline\ntitle=No exchange rates\n" + why
  const row = fields(answer)
  return row.row && !row.tone ? card(row) : answer
}
