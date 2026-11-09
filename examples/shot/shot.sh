#!/bin/sh
# title=Shot
# icon=camera.viewfinder
# detail=Take a picture of the screen and mark it
# shortcut=s
file=$(openspot screen shot) || exit 1
[ -n "$file" ] || exit 0
editor="$OPENSPOT_DATA/edit"
source="$(dirname "$0")/edit.swift"
if [ ! -x "$editor" ] || [ "$source" -nt "$editor" ]; then
  mkdir -p "$OPENSPOT_DATA"
  swiftc -O -o "$editor" "$source" 2>/dev/null || {
    echo "Openspot took the picture, but cannot build its editor. Install the Command Line Tools with \`xcode-select --install\`." >&2
    exit 1
  }
fi
"$editor" "$file"
openspot clipboard copy "$file" && echo "toast=Copied the picture."
