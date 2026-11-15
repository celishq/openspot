#!/bin/sh
# detail=Its charge, and the time left
# on=power.change
# offers=card
# offers=menubar
# `show <report>` draws a report of `pmset -g batt` that is given, such as the one of sample.sh.
if [ "$1" = show ] && [ -n "${2-}" ]; then report=$2; else report=$(pmset -g batt); fi
printf '%s\n' "$report" | awk '
  /InternalBattery/ && match($0, /[0-9]+%/) { line = $0 }
  !first && /[0-9]+%/ { first = $0 }
  END {
    if (line == "") line = first
    if (line == "") {
      printf "graph=battery\ntitle=–\ndetail=No battery\nicon=powerplug.fill\nvalue=0\n"
      exit
    }
    $0 = line
    match($0, /[0-9]+%/)
    percent = substr($0, RSTART, RLENGTH - 1) + 0
    symbol = "battery." int((percent + 12) / 25) * 25
    detail = match($0, /[0-9]+:[0-9]+/) ? substr($0, RSTART, RLENGTH) " left" : ""
    tone = ""
    if ($0 ~ /discharging/) {
      if (percent <= 20) tone = "bad"
    } else if ($0 ~ /charging|charged/) {
      symbol = "battery.100.bolt"
      detail = "Charging"
      tone = "good"
    }
    if (percent == 100) detail = "Full"
    printf "graph=battery\ntitle=%d%%\ndetail=%s\nicon=%s\nvalue=%s\ntone=%s\n", percent, (detail == "" ? "On battery" : detail), symbol, percent / 100, tone
  }'
