#!/bin/sh
# Draws the image under each example of GUIDE.md. A line ![...](docs/images/<name>.png) right after a sh example draws that
# example as an installed spot: its sheet, or its wide card when <name> ends in -card. A copy of the example goes beside the
# image as <name>.example, which GuideImageTests compare with the guide. OPENSPOT_APP names the app to draw with.
set -e
cd "$(dirname "$0")/.."
app=${OPENSPOT_APP:-.temp/dd/Build/Products/Debug/Openspot.app/Contents/MacOS/Openspot}
work=.temp/docs-images
rm -rf "$work"
mkdir -p "$work/plugins" "$work/config" "$work/core" "$work/examples" docs/images
awk -v out="$work/examples" '
  /^```sh$/ { inside = 1; text = ""; next }
  inside && /^```$/ { inside = 0; last = text; next }
  inside { text = text $0 "\n"; next }
  /^!\[[^]]*\]\(docs\/images\/[^)]*\.png\)$/ {
    name = $0; sub(/.*docs\/images\//, "", name); sub(/\.png\)$/, "", name)
    printf "%s", last > (out "/" name ".example"); close(out "/" name ".example")
    last = ""
  }
' GUIDE.md
for example in "$work"/examples/*.example; do
  name=$(basename "$example" .example)
  rm -f "$work"/plugins/*
  cp "$example" "$work/plugins/$name.sh"
  chmod +x "$work/plugins/$name.sh"
  case "$name" in
    *-card) size="--card wide" ;;
    *) size="" ;;
  esac
  OPENSPOT_PLUGINS="$PWD/$work/plugins" OPENSPOT_CONFIG="$PWD/$work/config" OPENSPOT_CORE="$PWD/$work/core" \
    "$app" render --spot "$name" $size "docs/images/$name.png"
  cp "$example" "docs/images/$name.example"
  echo "docs/images/$name.png"
done
