#!/bin/sh
# icon=eyedropper
# detail=Copy a color
# uses=screen,clipboard
# offers=card
color=$(openspot color pick) || exit 1
[ -n "$color" ] || exit 0
printf '%s' "$color" | openspot clipboard copy
echo "toast=Copied $color"
