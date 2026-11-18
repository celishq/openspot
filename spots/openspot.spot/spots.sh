#!/bin/sh
case "$1" in
  open) exec openspot grid edit ;;
  *)
    echo 'Spots cannot do that.' >&2
    exit 1
    ;;
esac
