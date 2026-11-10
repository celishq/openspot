#!/bin/sh
# read=30
pmset -g batt | awk '
  !found && match($0, /[0-9]+%/) {
    found = 1
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
    printf "gauge=battery\ntitle=%d%%\ndetail=%s\nicon=%s\nvalue=%s\ntone=%s\n", percent, (detail == "" ? "On battery" : detail), symbol, percent / 100, tone
  }
  END {
    if (!found) printf "gauge=battery\ntitle=–\ndetail=No battery\nicon=powerplug.fill\nvalue=0\n"
  }'
