#!/bin/sh
# icon=internaldrive
# on=clock.300
# offers=card
# offers=menubar
df -k /System/Volumes/Data | awk 'NR == 2 {
  used = $3 / ($3 + $4)
  printf "graph=disk\ntitle=%d%%\ndetail=%d GB free\nvalue=%.2f\n", used * 100, $4 / 1048576, used
}'
