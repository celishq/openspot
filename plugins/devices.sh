#!/bin/sh
# name=Devices
# symbol=airpods
# read=60
/usr/sbin/system_profiler SPBluetoothDataType 2>/dev/null | awk '
  /^      Connected:/ { on = 1; next }
  /^      [^ ]/ { on = 0 }
  on && /^          [^ ]/ { name = $0; sub(/^ +/, "", name); sub(/:$/, "", name); sub(/^.*’s /, "", name) }
  on && /Battery Level:/ && !/Case/ {
    level = $NF; sub("%", "", level)
    if (low == "" || level + 0 < low + 0) { low = level; lowName = name }
  }
  END {
    if (low == "") { printf "title=–\ndetail=No devices\nvalue=0\n"; exit }
    symbol = lowName ~ /AirPods/ ? "airpods" : lowName ~ /Keyboard/ ? "keyboard" : lowName ~ /Mouse/ ? "magicmouse" : "headphones"
    printf "title=%d%%\ndetail=%s\nsymbol=%s\nvalue=%.2f\ntone=%s\n", low, lowName, symbol, low / 100, (low <= 20 ? "bad" : "")
  }'
