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

# Prints the page of spot $1: its acts of each day, what it costs, how fast it answers, how it failed, its uses, and the
# spots it shows, is shown on, starts and is started by.
page() {
  openspot spot stats --days 14 | awk -v want="$1" '
    BEGIN { RS = ""; FS = "\n" }
    function seconds(s) { return s < 1 ? sprintf("%d ms", s * 1000 + 0.5) : sprintf("%.1f s", s) }
    function bytes(b) { return b >= 1048576 ? sprintf("%.0f MB", b / 1048576) : sprintf("%.0f KB", b / 1024) }
    function name(id) { return title[id] != "" ? title[id] : id }
    function perday(id) { return seen[id] > 0 ? cpu[id] / seen[id] : 0 }
    function join(list, part) { return list (list == "" ? "" : " · ") part }
    BEGIN { words["timeout"] = "timed out"; words["exit"] = "stopped with an error"; words["output"] = "printed what Openspot cannot read" }
    /^row=/ {
      n++; rec[n] = $0; id = substr($1, 5); ids[n] = id
      for (i = 2; i <= NF; i++) {
        if ($i ~ /^title=/) title[id] = substr($i, 7)
        else if ($i ~ /^cpu=/) cpu[id] = substr($i, 5)
        else if ($i ~ /^seen=/) seen[id] = substr($i, 6)
      }
    }
    END {
      for (r = 1; r <= n && ids[r] != want; r++) {}
      if (r > n) exit
      nf = split(rec[r], f, "\n")
      days = ""; counted = 0; reads = ""; calls = ""; kinds = ""; shows = ""; cost = 0; cards = ""; by = ""; ran = ""
      for (i = 1; i <= nf; i++) {
        k = f[i]; sub(/=.*/, "", k); x = substr(f[i], length(k) + 2)
        if (k == "days") { days = days "value=" (x == "-" ? 0 : x) "\n"; if (x != "-") counted++ }
        else if (k ~ /^reads\./) reads = join(reads, x " at " substr(k, 7))
        else if (k ~ /^call\./) calls = join(calls, substr(k, 6) " " x)
        else if (k ~ /^failures\./) kinds = join(kinds, x " " words[substr(k, 10)])
        else if (k == "shows") { shows = join(shows, name(x) " " seconds(perday(x))); cost += perday(x) }
        else if (k == "cards") cards = join(cards, name(x))
        else if (k ~ /^runs\.by\./) by = join(by, name(substr(k, 9)) " " x (x == 1 ? " time" : " times"))
        else if (k ~ /^ran\./) ran = join(ran, name(substr(k, 5)) " " x (x == 1 ? " time" : " times"))
        else v[k] = x
      }
      d = v["seen"] > 0 ? v["seen"] : 1
      if (shows != "") {
        printf "grid=cpu cpu\ngrid=shows shows\n\n"
        printf "number=cpu\nvalue=%.3f\ndisplay=%s\ntitle=CPU a day of the spots it shows\n\n", cost, seconds(cost)
        printf "text=shows\ntitle=Shows\ndetail=%s\n\n", shows
        exit
      }
      day = v["cpu"] / d
      printf "grid=acts acts\ngrid=perday cpu\ngrid=answers memory\n"
      if (cards != "") printf "grid=cards cards\n"
      if (by != "") printf "grid=by by\n"
      if (ran != "") printf "grid=ran ran\n"
      printf "grid=hidden hidden\ngrid=failures failures\ngrid=reads reads\ngrid=uses uses\n\n"
      printf "graph=acts\ntitle=Acts, last 14 days\n%s\n", days
      printf "number=perday\nvalue=%.1f\ntitle=acts a day\n\n", (counted ? v["acts"] / counted : 0)
      printf "number=cpu\nvalue=%.3f\ndisplay=%s\ntitle=CPU a day\n\n", day, seconds(day)
      printf "number=answers\nvalue=%s\ndisplay=%s\ntitle=Slow answers\n\n", v["p95"] + 0, (v["p95"] == "" ? "–" : seconds(v["p95"]))
      printf "number=memory\nvalue=%s\ndisplay=%s\ntitle=Peak memory\n\n", v["memory"] + 0, (v["memory"] == "" ? "–" : bytes(v["memory"]))
      if (cards != "") printf "text=cards\ntitle=Shown on\ndetail=%s\n\n", cards
      if (by != "") printf "text=by\ntitle=Started by\ndetail=%s\n\n", by
      if (ran != "") printf "text=ran\ntitle=Starts\ndetail=%s\n\n", ran
      printf "text=hidden\ntitle=While hidden\ndetail=%s CPU a day · %d wakeups\n\n", seconds(v["hidden.cpu"] / d), v["hidden.wakeups"] / d
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
# second, and is unused when 14 days of counts hold no act. A card of other spots runs nothing, so it shows what the
# spots on it cost. Openspot's own spots are left out.
printf '%s\n' "$frame" | awk '
  BEGIN { RS = ""; FS = "\n" }
  function seconds(s) { return s < 1 ? sprintf("%d ms", s * 1000 + 0.5) : sprintf("%.1f s", s) }
  function name(id) { return title[id] != "" ? title[id] : id }
  function perday(id) { return seen[id] > 0 ? cpu[id] / seen[id] : 0 }
  /^row=/ {
    n++; rec[n] = $0; id = substr($1, 5)
    for (i = 2; i <= NF; i++) {
      if ($i ~ /^title=/) title[id] = substr($i, 7)
      else if ($i ~ /^cpu=/) cpu[id] = substr($i, 5)
      else if ($i ~ /^seen=/) seen[id] = substr($i, 6)
    }
  }
  END {
    for (r = 1; r <= n; r++) {
      nf = split(rec[r], f, "\n")
      delete v; days = ""; counted = 0; shows = ""; cost = 0; via = ""
      for (i = 1; i <= nf; i++) {
        k = f[i]; sub(/=.*/, "", k); x = substr(f[i], length(k) + 2)
        if (k == "days") { days = days "value=" x "\n"; if (x != "-") counted++ }
        else if (k == "shows") { shows = shows (shows == "" ? "" : ", ") name(x); cost += perday(x) }
        else if (k == "cards") via = via (via == "" ? "On " : ", ") name(x)
        else if (k ~ /^runs\.by\./) via = via (via == "" ? "Started by " : ", ") name(substr(k, 9))
        else v[k] = x
      }
      id = v["row"]
      if (id ~ /^openspot\//) continue
      perday_acts = counted ? v["acts"] / counted : 0
      cpu_day = v["cpu"] / (v["seen"] > 0 ? v["seen"] : 1)
      if (shows != "") {
        state = "card"; order = 4; section = "Cards of other spots"; cpu_day = cost; days = ""
        detail = "Shows " shows " · " seconds(cost) " CPU a day"
      } else if (v["failures"] > 0) {
        state = "bad"; order = 2; section = "Failing"
        kind = v["failures.timeout"] > 0 ? "timed out" : v["failures.output"] > 0 ? "printed what Openspot cannot read" : "stopped with an error"
        detail = v["failures"] " of " v["runs"] " failed · " kind
      } else if (v["p95"] > 1) {
        state = "warn"; order = 3; section = "Slow to answer"
        detail = "95 in 100 answer within " seconds(v["p95"]) " · half within " seconds(v["p50"])
      } else if (counted >= 14 && v["acts"] == 0 && via == "") {
        state = "unused"; order = 5; section = "Unused for 14 days"
        detail = seconds(cpu_day) " CPU a day" (v["hidden.cpu"] > 0 ? ", " seconds(v["hidden.cpu"] / (v["seen"] > 0 ? v["seen"] : 1)) " while hidden" : "")
      } else {
        state = "used"; order = 1; section = "Used · last 14 days"
        detail = (v["acts"] == 0 && via != "" ? via : sprintf("%.1f a day", perday_acts)) " · " seconds(cpu_day) " CPU"
      }
      tone = state == "bad" ? "tone=bad\n" : state == "warn" ? "tone=warn\n" : ""
      block = "row=" id "\ntitle=" v["title"] "\ndetail=" detail "\nsection=" section "\npush=spot:" id "\n" tone days \
        sprintf("acts=%.2f\ncpu=%.3f\nstate=%s\n", perday_acts, cpu_day, state)
      gsub(/\n/, "\001", block)
      printf "%d\t%09.2f\t%s\n", order, 100000 - perday_acts * 100, block
      if (state != "card" && (topcpu == "" || cpu_day > topcpu)) { topcpu = cpu_day; toptitle = v["title"]; topdetail = seconds(cpu_day) " CPU a day" }
    }
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
