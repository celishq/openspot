#!/bin/sh
# title=CPU
# on=clock.5
# preview=sample
# offers=card
# offers=menubar
if [ "$OPENSPOT_REASON" = spot.preview ]; then
  printf 'graph=cpu\ntitle=23%%\nmax=100\n'; for v in 12 18 15 22 31 27 19 24 35 28 21 17 26 33 29 23; do printf 'value=%s\n' "$v"; done
  exit 0
fi
history="${TMPDIR:-/tmp}/openspot-cpu"

# Prints the use of all cores now, and the trend of the last points with the one of now. Only a read keeps the trend, so
# that a look from another script adds no point.
ps -A -o %cpu= | LC_ALL=C awk -v cores="$(/usr/sbin/sysctl -n hw.ncpu)" -v history="$history" -v kept="$history.$$" -v call="$1" '
  { sum += $1 }
  END {
    now = int(sum / cores)
    while ((getline line < history) > 0) if (line ~ /^[0-9]+$/) points[n++] = line
    first = n > 29 ? n - 29 : 0
    points[n++] = now
    printf "graph=cpu\ntitle=%d%%\nmax=100\n", now
    for (i = first; i < n; i++) {
      print "value=" points[i]
      if (call == "read") print points[i] > kept
    }
  }'
if [ "$1" = read ]; then mv "$history.$$" "$history"; fi
