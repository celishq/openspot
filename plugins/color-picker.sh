#!/bin/sh
# icon=eyedropper
# subtitle=Copy a color
# shortcut=o
# size=small
color=$(openspot color pick) || exit 1
[ -n "$color" ] || exit 0
printf '%s' "$color" | pbcopy
echo "toast=Copied $color"
