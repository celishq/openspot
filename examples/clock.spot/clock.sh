#!/bin/sh
# title=World clock
# icon=globe
# mode=always
# offers=card
# offers=menubar
. "$OPENSPOT_SH"
zone=Asia/Tokyo
city=$(printf '%s' "${zone##*/}" | tr _ ' ')

# Prints the time in the zone, with the city below it.
now() {
  printf 'text=time\ntitle=%s\ndetail=%s' "$(TZ=$zone date +%H:%M)" "$city"
}

# Prints the time again each time a new minute starts.
tick() {
  while sleep $((60 - $(date +%-S))); do
    printf '%s\n---\n' "$(now)"
  done
}

main() {
  case "$1" in
    read) now ;;
  esac
}

tick &
ticker=$!
trap 'pkill -P "$ticker"; kill "$ticker"' EXIT
trap 'exit' TERM
openspot_serve main "$@"
