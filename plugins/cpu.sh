#!/bin/sh
# name=CPU
# read=5
history="${TMPDIR:-/tmp}/openspot-cpu"
cores=$(/usr/sbin/sysctl -n hw.ncpu)
now=$(ps -A -o %cpu= | awk -v cores="$cores" '{sum += $1} END {printf "%d", sum / cores}')
{ [ -f "$history" ] && grep -E '^[0-9]+$' "$history" | tail -n 29; echo "$now"; } > "$history.$$"
mv "$history.$$" "$history"
printf 'title=%s%%\nmax=100\n' "$now"
sed 's/^/point=/' "$history"
