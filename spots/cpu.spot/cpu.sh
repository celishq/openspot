#!/bin/sh

# Prints the use of all cores: one point as a bar, or the points as a series.
draw() {
  [ $# -gt 0 ] || return 0
  if [ $# -eq 1 ]; then
    printf 'frame=\nclass=gap-part\n\nnumber=cpu\nclass=h-20 bar:flex\ntype=bar\ntitle=CPU\nmax=100\nunit=%%\nvalue=%s\n' "$1"
    return 0
  fi
  IFS=,
  printf 'frame=\nclass=gap-part\n\nseries=cpu\nclass=grow bar:flex\ntitle=CPU\nmax=100\nunit=%%\nvalue=%s\n' "$*"
  unset IFS
}

# Prints the use of all cores now.
measure() {
  ps -A -o %cpu= | LC_ALL=C awk -v cores="$(/usr/sbin/sysctl -n hw.ncpu)" '{ sum += $1 } END { print int(sum / cores) }'
}

# `show` draws the points that are given, such as the ones of sample.sh. With none, as when another spot such as System
# looks, it measures the use of all cores now, and keeps no point.
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
