#!/bin/sh
# Puts what you copied in the last 2 minutes in the panel's field, as a link or as text, where Tab offers it to each spot
# that takes it. Openspot counts the age of a copy from the first read after it.
fresh=120

case "$1" in
  show)
    copied=$(openspot read clipboard) || exit 0
    age=$(printf '%s\n' "$copied" | sed -n 's/^age=//p')
    [ -n "$age" ] && [ "$age" -lt "$fresh" ] || exit 0
    case "$copied" in
      text=*) printf '%s\ntitle=Copied text\n' "$copied" ;;
      *) printf '%s\n' "$copied" ;;
    esac | openspot attachment add
    ;;
esac
