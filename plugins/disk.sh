#!/bin/sh
# symbol=internaldrive
# read=300
df -k /System/Volumes/Data | awk 'NR == 2 {
  used = $3 / ($3 + $4)
  printf "title=%d%%\ndetail=%d GB free\nvalue=%.2f\n", used * 100, $4 / 1048576, used
}'
