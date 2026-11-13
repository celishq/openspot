#!/bin/sh
# title=Devices
# icon=airpods
# on=clock.300
# preview=sample
if [ "$OPENSPOT_REASON" = spot.preview ]; then
  printf 'graph=devices\ntitle=72%%\ndetail=AirPods Pro\nicon=airpods\nvalue=0.72\n'
  exit 0
fi
. "$OPENSPOT_SH"

# Prints one line for each battery of each connected device: its name, the part, then the level.
levels() {
  /usr/sbin/system_profiler SPBluetoothDataType 2>/dev/null | awk '
    /^      Connected:/ { on = 1; next }
    /^      [^ ]/ { on = 0 }
    on && /^          [^ ]/ { name = $0; sub(/^ +/, "", name); sub(/:$/, "", name); sub(/^.*’s /, "", name) }
    on && /Battery Level:/ {
      part = $0; sub(/^ +/, "", part); sub(/ ?Battery Level:.*/, "", part)
      level = $NF; sub("%", "", level)
      printf "%s\t%s\t%s\n", name, part, level
    }'
}

if [ "$1" = levels ]; then
  levels
  exit 0
fi
levels | awk -F'\t' '
  $2 != "Case" && (low == "" || $3 + 0 < low + 0) { low = $3; name = $1 }
  END {
    if (low == "") { printf "graph=devices\ntitle=–\ndetail=No devices\nvalue=0\n"; exit }
    symbol = name ~ /AirPods/ ? "airpods" : name ~ /Keyboard/ ? "keyboard" : name ~ /Mouse/ ? "magicmouse" : "headphones"
    printf "devices\t%d%%\t%s\t%s\tvalue=%.2f\t%s\n", low, name, symbol, low / 100, (low <= 20 ? "tone=bad" : "")
  }' | openspot_rows graph
