#!/bin/sh
set -e
out=${1:?usage: guide.sh <output file>}
cd "$(dirname "$0")/.."
pages=$(ls docs/protocol/*.md)
links=$(for page in $pages; do
  name=$(basename "$page")
  anchor=$(sed -n '1s/^# //p' "$page" | tr 'A-Z' 'a-z' | sed -e 's/[^a-z0-9 _-]//g' -e 's/ /-/g')
  printf 's|](docs/protocol/%s)|](#%s)|g\ns|](%s)|](#%s)|g\n' "$name" "$anchor" "$name" "$anchor"
done)
{ cat GUIDE.md; printf '\n'; cat PROTOCOL.md; for page in $pages; do printf '\n'; sed 's|](\.\./\.\./|](|g' "$page"; done; printf '\n'; cat USING.md; } |
  sed -e "$links" -e 's|](docs/protocol/[0-9a-z-]*\.md#|](#|g' -e 's|](\([0-9][0-9]-[a-z-]*\)\.md#|](#|g' \
    -e 's/](PROTOCOL\.md#/](#/g' -e 's/](GUIDE\.md#/](#/g' -e 's/](PROTOCOL\.md)/](#openspot-protocol)/g' -e 's/](GUIDE\.md)/](#openspot-guide)/g' -e 's/](USING\.md#/](#/g' -e 's/](USING\.md)/](#use-openspot)/g' > "$out.$$"
mv "$out.$$" "$out"
