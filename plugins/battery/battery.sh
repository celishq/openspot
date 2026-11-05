#!/bin/sh
[ "$1 $2" = "metric level" ] || exit 1
line=$(pmset -g batt | grep -E '[0-9]+%')
if [ -z "$line" ]; then
  echo '{"title":"–","detail":"No battery","symbol":"powerplug.fill","value":0}'
  exit 0
fi
percent=$(printf '%s' "$line" | grep -oE '[0-9]+%' | tr -d '%')
symbol=battery.$(( (percent + 12) / 25 * 25 ))
detail=$(printf '%s' "$line" | grep -oE '[0-9]+:[0-9]+' | head -1)
detail="${detail:+$detail left}"
tone=""
case "$line" in
  *discharging*) [ "$percent" -le 20 ] && tone=',"tone":"bad"' ;;
  *charging*|*charged*) symbol=battery.100.bolt; detail="Charging"; tone=',"tone":"good"' ;;
esac
[ "$percent" = 100 ] && detail="Full"
printf '{"title":"%s%%","detail":"%s","symbol":"%s","value":%s%s}\n' "$percent" "${detail:-On battery}" "$symbol" "$(awk "BEGIN{print $percent/100}")" "$tone"
