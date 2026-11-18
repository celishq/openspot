#!/bin/sh

# Prints the use of all cores, the last of the points, with each point as a bar.
draw() {
  [ $# -gt 0 ] || return 0
  eval "now=\${$#}"
  printf 'graph=cpu\ntitle=%s%%\nmax=100\n' "$now"
  for point; do printf 'value=%s\n' "$point"; done
}

# Prints the use of all cores now.
measure() {
  ps -A -o %cpu= | LC_ALL=C awk -v cores="$(/usr/sbin/sysctl -n hw.ncpu)" '{ sum += $1 } END { print int(sum / cores) }'
}

# `show` draws the points that are given, such as the ones of sample.sh. With none, as when another spot such as System
# details looks, it measures the use of all cores now, and keeps no point.
if [ "$1" = show ]; then
  shift
  [ $# -gt 0 ] || set -- $(measure)
  draw "$@"
  exit 0
fi

. "$OPENSPOT_SH"
kept="$OPENSPOT_DATA/trend"
points=

# Starts from the trend that the last process kept, and skips a line that is not a number.
if [ -f "$kept" ]; then
  while IFS= read -r line; do
    case $line in '' | *[!0-9]*) ;; *) points="$points $line" ;; esac
  done < "$kept"
fi

# Prints the use of all cores, from the load that Openspot measures every 5 seconds, and the trend of the last 30 points.
# A read with no load, as when the panel opens, measures the use now after the trend, and keeps no point.
main() {
  load=$(value event.value)
  case "$1:$load" in
    show:cpu=*)
      now=${load#cpu=}
      now=${now%% *}
      set -- $points "$now"
      [ $# -le 30 ] || shift $(($# - 30))
      points="$*"
      draw $points
      ;;
    *) draw $points $(measure) ;;
  esac
}

openspot_serve main "$@"

# The trend survives this process: it is written beside its file, then moved over it.
[ -n "$points" ] || exit 0
printf '%s\n' $points > "$kept.$$" && mv "$kept.$$" "$kept"
