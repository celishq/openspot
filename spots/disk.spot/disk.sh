#!/bin/sh
# `show <report>` draws a report of `df -k` that is given, such as the one of sample.sh.
if [ "$1" = show ] && [ -n "${2-}" ]; then report=$2; else report=$(df -k /System/Volumes/Data); fi
printf '%s\n' "$report" | awk 'NR == 2 {
  used = $3 / ($3 + $4)
  printf "frame=\ngrid=disk\ngrid=disk\ngrid.bar=disk\n\ngraph=disk\ntitle=%d%%\ndetail=%d GB free\nvalue=%.2f\n", used * 100, $4 / 1048576, used
}'
