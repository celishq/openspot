#!/bin/sh
# title=Devices
# icon=airpods
# detail=The lowest battery of your Bluetooth devices
# on=device.connect
# offers=card
# offers=menubar
. "$OPENSPOT_SH"

# Prints one line for each battery of each connected device: its name, the part, then the level.
levels() {
  system_profiler SPBluetoothDataType 2>/dev/null | awk '
    /^      Connected:/ { on = 1; next }
    /^      [^ ]/ { on = 0 }
    on && /^          [^ ]/ { name = $0; sub(/^ +/, "", name); sub(/:$/, "", name); sub(/^.*’s /, "", name) }
    on && /Battery Level:/ {
      part = $0; sub(/^ +/, "", part); sub(/ ?Battery Level:.*/, "", part)
      level = $NF; sub("%", "", level)
      printf "%s\t%s\t%s\n", name, part, level
    }'
}

# Prints the frame of the lowest level of the lines of `levels` on stdin, but a case's.
draw() {
  awk -F'\t' '
  $2 != "Case" && (low == "" || $3 + 0 < low + 0) { low = $3; name = $1 }
  END {
    if (low == "") { printf "graph=devices\ntitle=–\ndetail=No devices\nvalue=0\n"; exit }
    symbol = name ~ /AirPods/ ? "airpods" : name ~ /Keyboard/ ? "keyboard" : name ~ /Mouse/ ? "magicmouse" : "headphones"
    printf "devices\t%d%%\t%s\t%s\tvalue=%.2f\t%s\n", low, name, symbol, low / 100, (low <= 20 ? "tone=bad" : "")
  }' | openspot_rows graph
}

case $1 in
  levels) levels; exit 0 ;;
  show) printf '%s\n' "${2-}" | draw; exit 0 ;;
esac

# A device that connects asks again at once. Another read asks again only after 5 minutes, since the levels move
# slowly and the Bluetooth report takes a second: until then it shows the frame it kept, whose first line is its time.
kept="$OPENSPOT_DATA/frame"
now=$(/bin/date +%s)
if [ "$OPENSPOT_REASON" != device.connect ] && [ -f "$kept" ]; then
  { IFS= read -r made && [ $((now - made)) -lt 300 ] && /bin/cat; } < "$kept" && exit 0
fi
frame=$(levels | draw)
printf '%s\n' "$frame"
printf '%s\n%s\n' "$now" "$frame" > "$kept.$$" && /bin/mv "$kept.$$" "$kept"
