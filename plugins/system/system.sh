#!/bin/sh
[ "$1" = metric ] || exit 1
case "$2" in
  cpu)
    history="${TMPDIR:-/tmp}/openspot-cpu"
    cores=$(/usr/sbin/sysctl -n hw.ncpu)
    now=$(ps -A -o %cpu= | awk -v cores="$cores" '{sum += $1} END {printf "%d", sum / cores}')
    { [ -f "$history" ] && grep -E '^[0-9]+$' "$history" | tail -n 29; echo "$now"; } > "$history.$$"
    mv "$history.$$" "$history"
    printf 'title=%s%%\nmax=100\n' "$now"
    sed 's/^/point=/' "$history"
    ;;
  disk)
    df -k /System/Volumes/Data | awk 'NR == 2 {
      used = $3 / ($3 + $4)
      printf "title=%d%%\ndetail=%d GB free\nsymbol=internaldrive\nvalue=%.2f\n", used * 100, $4 / 1048576, used
    }'
    ;;
  *) exit 1 ;;
esac
