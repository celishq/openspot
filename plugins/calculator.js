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

/** The row of the answer of a sum, a conversion or a date for a read, or the copy of the plain value of a picked row. */
function main([id, text]) {
  if (id === "open") {
    if (text === "offline" || openspot.call(["clipboard", "copy"], text).code !== 0) return ""
    return openspot.frame({ toast: `Copied ${text}` })
  }
  if (!text) return ""
  const answer = openspot.call(["calc", "solve", text]).stdout
  const why = noRates[answer.trim()]
  return why ? "row=offline\ntitle=No exchange rates\n" + why : answer
}
