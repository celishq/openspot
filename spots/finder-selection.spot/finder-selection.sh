#!/bin/sh
# Puts the files selected in the front Finder window in the panel's field, where Tab offers them to each spot that
# takes them. It reads the selection only when Tab picks its chip over Finder.
case "$1" in
  attach)
    picked=$(openspot finder selection) || exit 0
    if [ -n "$picked" ]; then
      printf '%s\n' "$picked" | openspot attachment add
    else
      openspot attachment empty "Nothing selected in Finder"
    fi
    ;;
esac
