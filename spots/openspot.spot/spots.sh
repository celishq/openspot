#!/bin/sh
# title=Spots
# icon=puzzlepiece.extension
# detail=Edit Spots
# keywords=edit spots
case "$1" in
  open) exec openspot spot store ;;
  *)
    echo 'Spots cannot do that.' >&2
    exit 1
    ;;
esac
