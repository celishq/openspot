#!/bin/sh
# symbol=eyedropper
# subtitle=Copy a color
# key=o
# size=small
color=$("$OPENSPOT_APP" --pick-color) || exit 1
[ -n "$color" ] || exit 0
printf '%s' "$color" | pbcopy
echo "toast=Copied $color"
