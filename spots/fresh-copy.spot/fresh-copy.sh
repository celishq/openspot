#!/bin/sh
# Puts what you copied in the last 2 minutes in the panel's field, as a link or as text, where Tab offers it to each spot
# that takes it. Openspot counts the age of a copy from the first time it sees it.
case "$1" in
  show)
    copied=$(openspot clipboard read --newer 120 | head -c 100000)
    [ -n "$(printf '%s' "$copied" | tr -d '[:space:]')" ] || exit 0
    if [ "$(printf '%s' "$copied" | wc -l)" -eq 0 ] && printf '%s' "$copied" | grep -Eq '^https?://[^[:space:]]+$'; then
      openspot attachment add url="$copied"
    else
      openspot attachment add text="$copied" title="Copied text"
    fi
    ;;
esac
