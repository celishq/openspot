#!/bin/sh
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
  printf 'frame=\nclass=gap-part\n'
  awk -F'\t' '
  $2 != "Case" && (low == "" || $3 + 0 < low + 0) { low = $3; name = $1 }
  END {
    if (low == "") { printf "devices\tDevices\tNo devices\t\tclass=h-20 bar:flex\tdisplay=–\tvalue=0\tmax=100\n"; exit }
    symbol = name ~ /AirPods/ ? "airpods" : name ~ /Keyboard/ ? "keyboard" : name ~ /Mouse/ ? "magicmouse" : "headphones"
    printf "devices\tDevices\t%s\t%s\tclass=h-20 bar:flex\tvalue=%d\tmax=100\tunit=%%\t%s\n", name, symbol, low, (low <= 20 ? "tone=bad" : "")
  }' | openspot_items number
}

case $1 in
  levels) levels; exit 0 ;;
  show) [ $# -lt 2 ] || { printf '%s\n' "$2" | draw; exit 0; } ;;
esac

# A device that connects asks again at once. Another read asks again only after 5 minutes, since the levels move
# slowly and the Bluetooth report takes a second: until then it shows the frame it kept, whose first line is its time.
kept="$OPENSPOT_DATA/frame"
now=$(/bin/date +%s)
if [ "$(value event)" != device.connect ] && [ -f "$kept" ]; then
  { IFS= read -r made && [ $((now - made)) -lt 300 ] && /bin/cat; } < "$kept" && exit 0
fi
frame=$(levels | draw)
printf '%s\n' "$frame"
printf '%s\n%s\n' "$now" "$frame" > "$kept.$$" && /bin/mv "$kept.$$" "$kept"
