#!/bin/sh
# icon=internaldrive
# on=clock.300
# preview=sample
# offers=card
# offers=menubar
if [ "$OPENSPOT_REASON" = spot.preview ]; then
  printf 'graph=disk\ntitle=58%%\ndetail=412 GB free\nvalue=0.58\n'
  exit 0
fi
df -k /System/Volumes/Data | awk 'NR == 2 {
  used = $3 / ($3 + $4)
  printf "graph=disk\ntitle=%d%%\ndetail=%d GB free\nvalue=%.2f\n", used * 100, $4 / 1048576, used
}'
