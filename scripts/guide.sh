#!/bin/sh
set -e
out=${1:?usage: guide.sh <output file>}
cd "$(dirname "$0")/.."
pages=$(grep -o '](docs/[^)#]*\.md)' PROTOCOL.md | sed -e 's/^](//' -e 's/)$//' | awk '!seen[$0]++')
links=$(for page in PROTOCOL.md $pages USING.md; do
  name=$(basename "$page" .md)
  anchor=$(sed -n '1s/^# //p' "$page" | tr 'A-Z' 'a-z' | sed -e 's/[^a-z0-9 _-]//g' -e 's/ /-/g')
  printf 's|\\]\\((\\.\\./)*(docs/)?([a-z]+/)?%s\\.md\\)|](#%s)|g\n' "$name" "$anchor"
  printf 's|\\]\\((\\.\\./)*(docs/)?([a-z]+/)?%s\\.md#|](#|g\n' "$name"
done)
for page in PROTOCOL.md $pages USING.md; do printf '\n'; cat "$page"; done | sed '1d' |
  sed -E -e "$links" -e 's|\]\((\.\./)+|](|g' > "$out.$$"
mv "$out.$$" "$out"
