#!/bin/sh
case "$1" in
  edit) exec openspot grid edit ;;
  show) ;;
  *)
    echo 'Spots cannot do that.' >&2
    exit 1
    ;;
esac
