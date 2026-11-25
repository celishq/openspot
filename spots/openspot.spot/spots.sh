#!/bin/sh
. "$OPENSPOT_SH"

# /spots lists every spot of yours, the ones off the grid first; Pin to grid puts one in the first free slot.
case "$1" in
  edit) exec openspot grid edit ;;
  command|show)
    openspot grid list
    printf 'button=pin\ntitle=Pin to grid\nicon=pin\nclose=false\n'
    ;;
  pin) exec openspot grid pin "$(value item)" ;;
  *)
    echo 'Spots cannot do that.' >&2
    exit 1
    ;;
esac
