#!/bin/sh
# icon=eyedropper
# detail=Copy a color
# size=small
# uses=screen,clipboard
color=$(openspot color pick) || exit 1
[ -n "$color" ] || exit 0
printf '%s' "$color" | openspot clipboard copy
echo "toast=Copied $color"
