#!/bin/sh
# title=CPU
# read=5
history="${TMPDIR:-/tmp}/openspot-cpu"
cores=$(/usr/sbin/sysctl -n hw.ncpu)
now=$(ps -A -o %cpu= | awk -v cores="$cores" '{sum += $1} END {printf "%d", sum / cores}')
points=$({ [ -f "$history" ] && grep -E '^[0-9]+$' "$history" | tail -n 29; echo "$now"; })

# Keeps the points with the one of now as the trend. Only a read keeps them, so that a look from another script adds none.
keep() {
  printf '%s\n' "$points" > "$history.$$"
  mv "$history.$$" "$history"
}

[ "$1" = read ] && keep
printf 'graph=cpu\ntitle=%s%%\nmax=100\n' "$now"
printf '%s\n' "$points" | sed 's/^/point=/'
