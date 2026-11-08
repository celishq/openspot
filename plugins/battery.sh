#!/bin/sh
# read=30
line=$(pmset -g batt | grep -E '[0-9]+%')
if [ -z "$line" ]; then
  printf 'gauge=battery\ntitle=–\ndetail=No battery\nicon=powerplug.fill\nvalue=0\n'
  exit 0
fi
percent=$(printf '%s' "$line" | grep -oE '[0-9]+%' | tr -d '%')
symbol=battery.$(( (percent + 12) / 25 * 25 ))
detail=$(printf '%s' "$line" | grep -oE '[0-9]+:[0-9]+' | head -1)
detail="${detail:+$detail left}"
tone=""
case "$line" in
  *discharging*) [ "$percent" -le 20 ] && tone=bad ;;
  *charging*|*charged*) symbol=battery.100.bolt; detail="Charging"; tone=good ;;
esac
[ "$percent" = 100 ] && detail="Full"
printf 'gauge=battery\ntitle=%s%%\ndetail=%s\nicon=%s\nvalue=%s\ntone=%s\n' "$percent" "${detail:-On battery}" "$symbol" "$(awk "BEGIN{print $percent/100}")" "$tone"
