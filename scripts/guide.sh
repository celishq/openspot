#!/bin/sh
set -e
out=${1:?usage: guide.sh <output file>}
cd "$(dirname "$0")/.."
pages=$(grep -o '](docs/[^)#]*\.md)' PROTOCOL.md | sed -e 's/^](//' -e 's/)$//' | awk '!seen[$0]++')
anchor() {
  sed -n '1s/^# //p' "$1" | tr 'A-Z' 'a-z' | sed -e 's/[^a-z0-9 _-]//g' -e 's/ /-/g'
}
links=$(for page in PROTOCOL.md $pages MANUAL.md; do
  name=$(basename "$page" .md)
  printf 's|\\]\\((\\.\\./)*(docs/)?([a-z]+/)?%s\\.md\\)|](#%s)|g\n' "$name" "$(anchor "$page")"
  printf 's|\\]\\((\\.\\./)*(docs/)?([a-z]+/)?%s\\.md#|](#%s/|g\n' "$name" "$(anchor "$page")"
done)
for page in PROTOCOL.md $pages MANUAL.md; do
  printf '\n'
  sed -E "s|\\]\\(#|](#$(anchor "$page")/|g" "$page"
done | sed '1d' |
  sed -E -e "$links" -e 's|\]\((\.\./)+|](|g' > "$out.$$"
mv "$out.$$" "$out"
