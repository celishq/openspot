#!/bin/sh
. "$(dirname "$0")/checks.sh"
need app/Shell
found=$(grep -rnE --include='*.swift' 'NSVisualEffectView|"backdrop"|CAFilter|gaussianBlur|setValue\([^)]*forKeyPath:' app/Shell)
if [ -n "$found" ]; then
  echo "Shell draws glass by a private layer or a visual effect view. Use glassEffect, as Shell/Surface does:" >&2
  echo "$found" >&2
  exit 1
fi
echo "Glass check passed."
