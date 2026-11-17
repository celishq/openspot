#!/bin/sh
# title=Running spots
# icon=gauge.with.dots.needle.33percent
# detail=Use and cost of each spot
# on=sheet.open
# view=chart.swift
# offers=card

# A row or a dot opens its spot.
case "$1" in
  open | chart) exec openspot spot open "$2" ;;
esac

frame=$(openspot spot stats --days 14) || exit 1

# Prints the sheet: the chart, then a row for each spot under the title of its state, with a bar for the acts of each
# day. A spot fails when a call failed in the last 14 days, is slow when 95 in 100 of its calls answer in more than a
# second, and is unused when 14 days of counts hold no act. Openspot's own spots are left out.
printf '%s\n' "$frame" | awk '
  BEGIN { RS = ""; FS = "\n" }
  function seconds(s) { return s < 1 ? sprintf("%d ms", s * 1000 + 0.5) : sprintf("%.1f s", s) }
  !/^row=/ { next }
  {
    delete v; days = ""; counted = 0
    for (i = 1; i <= NF; i++) {
      k = $i; sub(/=.*/, "", k); x = substr($i, length(k) + 2)
      if (k == "days") { days = days "value=" x "\n"; if (x != "-") counted++ } else v[k] = x
    }
    id = v["row"]
    if (id ~ /^openspot\//) next
    perday = counted ? v["acts"] / counted : 0
    cpu = v["cpu"] / (counted ? counted : 1)
    if (v["failures"] > 0) {
      state = "bad"; order = 2; section = "Failing"
      kind = v["failures.timeout"] > 0 ? "timed out" : v["failures.output"] > 0 ? "printed what Openspot cannot read" : "stopped with an error"
      detail = v["failures"] " of " v["runs"] " failed · " kind
    } else if (v["p95"] > 1) {
      state = "warn"; order = 3; section = "Slow to answer"
      detail = "95 in 100 answer within " seconds(v["p95"]) " · half within " seconds(v["p50"])
    } else if (counted >= 14 && v["acts"] == 0) {
      state = "unused"; order = 4; section = "Unused for 14 days"
      detail = seconds(cpu) " CPU a day" (v["hidden.cpu"] > 0 ? ", " seconds(v["hidden.cpu"] / counted) " while hidden" : "")
    } else {
      state = "used"; order = 1; section = "Used · last 14 days"
      detail = sprintf("%.1f a day · ", perday) seconds(cpu) " CPU"
    }
    tone = state == "bad" ? "tone=bad\n" : state == "warn" ? "tone=warn\n" : ""
    block = "row=" id "\ntitle=" v["title"] "\ndetail=" detail "\nsection=" section "\n" tone days \
      sprintf("acts=%.2f\ncpu=%.3f\nstate=%s\n", perday, cpu, state)
    gsub(/\n/, "\001", block)
    printf "%d\t%09.2f\t%s\n", order, 100000 - perday * 100, block
    if (topcpu == "" || cpu > topcpu) { topcpu = cpu; toptitle = v["title"]; topdetail = seconds(cpu) " CPU a day" }
  }
  END {
    if (toptitle == "") toptitle = "No spot ran yet"
    printf "0\t0\ttext=top\001title=%s\001detail=%s\001\n", toptitle, topdetail
  }
' | sort -t "$(printf '\t')" -k1,1n -k2,2 | {
  printf 'grid=chart\ngrid=chart\ngrid=chart\ngrid=chart\ngrid=spots\ngrid.small=top\nrecents=false\n\n'
  printf 'view=chart\ngrow=false\n\n'
  first=1
  while IFS="$(printf '\t')" read -r _ _ block; do
    printf '%s\n' "$block" | tr '\001' '\n'
    if [ "$first" = 1 ]; then printf 'repeat=spots\n\n'; first=0; fi
  done
}
