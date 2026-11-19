#!/bin/sh
[ "$1" != show ] || exit 0
color=$(openspot color pick) || exit 1
[ -n "$color" ] || exit 0
printf '%s' "$color" | openspot clipboard copy
openspot toast "Copied $color"
