#!/bin/sh
# title=CPU
# read=5
history="${TMPDIR:-/tmp}/openspot-cpu"

# Prints the use of all cores now, and the trend of the last points with the one of now. Only a read keeps the trend, so
# that a look from another script adds no point.
ps -A -o %cpu= | awk -v cores="$(/usr/sbin/sysctl -n hw.ncpu)" -v history="$history" -v kept="$history.$$" -v call="$1" '
  { sum += $1 }
  END {
    now = int(sum / cores)
    while ((getline line < history) > 0) if (line ~ /^[0-9]+$/) points[n++] = line
    first = n > 29 ? n - 29 : 0
    points[n++] = now
    printf "graph=cpu\ntitle=%d%%\nmax=100\n", now
    for (i = first; i < n; i++) {
      print "point=" points[i]
      if (call == "read") print points[i] > kept
    }
  }'
if [ "$1" = read ]; then mv "$history.$$" "$history"; fi
