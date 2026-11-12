#!/bin/sh
# title=Memory
# icon=memorychip
# on=clock.5
/usr/bin/memory_pressure -Q | awk -F': ' -v level="$(/usr/sbin/sysctl -n kern.memorystatus_vm_pressure_level)" '
  /free percentage/ { sub("%", "", $2); free = $2 }
  END {
    used = 100 - (free == "" ? 100 : free)
    if (level == 4) { detail = "Pressure critical"; tone = "bad" }
    else if (level == 2) { detail = "Pressure high"; tone = "warn" }
    else { detail = "Pressure normal"; tone = "" }
    printf "graph=memory\ntitle=%d%%\ndetail=%s\nvalue=%s\ntone=%s\n", used, detail, used / 100, tone
  }'
