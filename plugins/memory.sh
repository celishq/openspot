#!/bin/sh
# title=Memory
# icon=memorychip
# read=5
free=$(/usr/bin/memory_pressure -Q | awk -F': ' '/free percentage/ { sub("%", "", $2); print $2 }')
used=$((100 - ${free:-100}))
case $(/usr/sbin/sysctl -n kern.memorystatus_vm_pressure_level) in
  4) detail="Pressure critical"; tone=bad ;;
  2) detail="Pressure high"; tone=warn ;;
  *) detail="Pressure normal"; tone="" ;;
esac
printf 'gauge=memory\ntitle=%s%%\ndetail=%s\nvalue=%s\ntone=%s\n' "$used" "$detail" "$(awk "BEGIN{print $used/100}")" "$tone"
