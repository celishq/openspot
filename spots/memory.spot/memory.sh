#!/bin/sh

# Prints the memory in use, as a share of the whole, with a tone when little is left.
draw() {
  used=$1
  if [ "$used" -ge 95 ]; then detail="Almost full" tone=bad
  elif [ "$used" -ge 85 ]; then detail="Little left" tone=warn
  else detail="In use" tone=
  fi
  printf 'frame=\nclass=gap-part\n\nnumber=memory\nclass=h-20 bar:flex\ntype=bar\ntitle=Memory\nvalue=%s\nmax=100\nunit=%%\ndetail=%s\ntone=%s\n' "$used" "$detail" "$tone"
}

# Prints the memory in use now, as a percent.
measure() {
  printf '%s' "$((100 - $(/usr/sbin/sysctl -n kern.memorystatus_level)))"
}

# `show <percent>` draws the share that is given, such as the one of sample.sh. With none, as when another spot such as
# System looks, it measures the memory now.
if [ "$1" = show ]; then
  draw "${2:-$(measure)}"
  exit 0
fi

. "$OPENSPOT_SH"
used=

# Prints the memory from the load that Openspot measures every 5 seconds. A read with no load, as when the panel
# opens, measures the memory now.
main() {
  load=$(value event.value)
  case $load in
    *memory=*) used=${load##*memory=} used=${used%% *} ;;
    *) used=$(measure) ;;
  esac
  draw "$used"
}

openspot_serve main "$@"
