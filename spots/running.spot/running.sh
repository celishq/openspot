#!/bin/sh
# title=Usage
# keywords=Running spots, statistics
# icon=gauge.with.dots.needle.33percent
# detail=Use and cost of each spot
# on=sheet.open
# view=chart.swift
# offers=card
# pages=spot:*
# uses=spots

# Prints the page of spot $1: its acts of each day, what it costs, how fast it answers, how it failed, and its uses.
page() {
  openspot spot stats --days 14 --spot "$1" | awk '
    BEGIN { RS = ""; FS = "\n" }
    function seconds(s) { return s < 1 ? sprintf("%d ms", s * 1000 + 0.5) : sprintf("%.1f s", s) }
    BEGIN { words["timeout"] = "timed out"; words["exit"] = "stopped with an error"; words["output"] = "printed what Openspot cannot read" }
    function bytes(b) { return b >= 1048576 ? sprintf("%.0f MB", b / 1048576) : sprintf("%.0f KB", b / 1024) }
    !/^row=/ { next }
    {
      delete v; days = ""; counted = 0; reads = ""; calls = ""; kinds = ""
      for (i = 1; i <= NF; i++) {
        k = $i; sub(/=.*/, "", k); x = substr($i, length(k) + 2)
        if (k == "days") { days = days "value=" (x == "-" ? 0 : x) "\n"; if (x != "-") counted++ }
        else if (k ~ /^reads\./) reads = reads (reads == "" ? "" : " · ") x " at " substr(k, 7)
        else if (k ~ /^call\./) calls = calls (calls == "" ? "" : " · ") substr(k, 6) " " x
        else if (k ~ /^failures\./) kinds = kinds (kinds == "" ? "" : " · ") x " " words[substr(k, 10)]
        else v[k] = x
      }
      n = v["seen"] > 0 ? v["seen"] : 1
      printf "grid=acts acts\ngrid=perday cpu\ngrid=answers memory\ngrid=hidden hidden\ngrid=failures failures\ngrid=reads reads\ngrid=uses uses\n\n"
      printf "graph=acts\ntitle=Acts, last 14 days\n%s\n", days
      printf "number=perday\nvalue=%.1f\ntitle=acts a day\n\n", (counted ? v["acts"] / counted : 0)
      printf "number=cpu\nvalue=%.3f\ndisplay=%s\ntitle=CPU a day\n\n", v["cpu"] / n, seconds(v["cpu"] / n)
      printf "number=answers\nvalue=%s\ndisplay=%s\ntitle=Slow answers\n\n", v["p95"] + 0, (v["p95"] == "" ? "–" : seconds(v["p95"]))
      printf "number=memory\nvalue=%s\ndisplay=%s\ntitle=Peak memory\n\n", v["memory"] + 0, (v["memory"] == "" ? "–" : bytes(v["memory"]))
      printf "text=hidden\ntitle=While hidden\ndetail=%s CPU a day · %d wakeups\n\n", seconds(v["hidden.cpu"] / n), v["hidden.wakeups"] / n
      if (v["failures"] > 0) printf "text=failures\ntitle=Failures\ndetail=%s of %s calls · %s\ntone=bad\n\n", v["failures"], v["runs"], kinds
      else printf "text=failures\ntitle=Failures\ndetail=None of %s calls\n\n", v["runs"] + 0
      printf "text=reads\ntitle=Reads\ndetail=%s\n\n", (reads == "" ? "None" : reads)
      printf "text=uses\ntitle=Uses\ndetail=%s\n\n", (calls == "" ? "None" : calls)
    }
  '
  printf 'button=open\ntitle=Open\nshortcut=return\n\nbutton=settings\ntitle=Settings\n\nbutton=delete\ntitle=Move to Trash\nconfirm=Press again to move it to the Trash\n'
}

case "$OPENSPOT_PAGE" in
  spot:*)
    id=${OPENSPOT_PAGE#spot:}
    case "$1" in
      open) exec openspot spot open "$id" ;;
      settings) exec openspot spot settings "$id" ;;
      delete) openspot spot delete "$id" && printf 'pop=true\n' ; exit ;;
    esac
    page "$id"
    exit
    ;;
esac

# A dot pushes the page of its spot.
case "$1" in
  chart) printf 'push=spot:%s\npush.title=%s\n' "$2" "$(openspot spot stats --days 14 --spot "$2" | sed -n 's/^title=//p' | head -n 1)"; exit ;;
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
    seen = v["seen"] > 0 ? v["seen"] : 1
    cpu = v["cpu"] / seen
    if (v["failures"] > 0) {
      state = "bad"; order = 2; section = "Failing"
      kind = v["failures.timeout"] > 0 ? "timed out" : v["failures.output"] > 0 ? "printed what Openspot cannot read" : "stopped with an error"
      detail = v["failures"] " of " v["runs"] " failed · " kind
    } else if (v["p95"] > 1) {
      state = "warn"; order = 3; section = "Slow to answer"
      detail = "95 in 100 answer within " seconds(v["p95"]) " · half within " seconds(v["p50"])
    } else if (counted >= 14 && v["acts"] == 0) {
      state = "unused"; order = 4; section = "Unused for 14 days"
      detail = seconds(cpu) " CPU a day" (v["hidden.cpu"] > 0 ? ", " seconds(v["hidden.cpu"] / seen) " while hidden" : "")
    } else {
      state = "used"; order = 1; section = "Used · last 14 days"
      detail = sprintf("%.1f a day · ", perday) seconds(cpu) " CPU"
    }
    tone = state == "bad" ? "tone=bad\n" : state == "warn" ? "tone=warn\n" : ""
    block = "row=" id "\ntitle=" v["title"] "\ndetail=" detail "\nsection=" section "\npush=spot:" id "\n" tone days \
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
