#!/bin/sh
. "$(dirname "$0")/checks.sh"
need app/Shell
found=$(grep -rnE --include='*.swift' 'NSVisualEffectView|"backdrop"|CAFilter|gaussianBlur|setValue\([^)]*forKeyPath:' app/Shell | grep -v '^app/Shell/Surface/SpotBackdropBlur\.swift:')
if [ -n "$found" ]; then
  echo "Shell draws glass by a private layer or a visual effect view. Use glassEffect, as Shell/Surface does. Only SpotBackdropBlur may:" >&2
  echo "$found" >&2
  exit 1
fi
bare=$(grep -rlE --include='*.swift' 'cacheDisplay' app/Shell/Picture 2>/dev/null | while read -r file; do
  grep -qE '\\\.spotDrawsGlass,' "$file" || echo "$file"
done)
if [ -n "$bare" ]; then
  echo "A picture is drawn off screen with system glass on, which draws wrongly there. Draw it through SpotPicture:" >&2
  echo "$bare" >&2
  exit 1
fi
faded=$(grep -rnE --include='*.swift' 'gridShade' app/Shell | grep -vE '^app/Shell/Grid/SpotMenuDim\.swift:')
if [ -n "$faded" ]; then
  echo "A view reads the shade of the grid, so it runs again when a menu opens. Only SpotMenuDim may:" >&2
  echo "$faded" >&2
  exit 1
fi
faded=$(grep -rnE --include='*.swift' 'environment\(\\\.spotFade,' app/Shell | grep -vE '^app/Shell/(Surface/SpotFadeLook|Field/SpotFieldView)\.swift:')
if [ -n "$faded" ]; then
  echo "A view fades the glass under it one by one. Fade many glass surfaces by one layer over them (see Motion in AGENTS.md):" >&2
  echo "$faded" >&2
  exit 1
fi
echo "Glass check passed."
