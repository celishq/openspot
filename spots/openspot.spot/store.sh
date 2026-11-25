#!/bin/sh
. "$OPENSPOT_SH"

# A search ends with a row that opens the Store with the typed words in its search.
case "$1" in
  open)
    exec openspot store open
    ;;
  search)
    text=$(value text | awk '{ sub(/^[ \t]+/, ""); sub(/[ \t]+$/, ""); print }')
    [ -z "$text" ] || openspot_item "$text" "Look in the Store for “${text}”" '' bag
    ;;
  press)
    exec openspot store open --search "$(value item)"
    ;;
  *)
    echo 'Store cannot do that.' >&2
    exit 1
    ;;
esac
