#!/bin/sh
# Joins the specs 00 to 09 into the one guide that the app bundles and that an AI reads. Edit the specs, then run this.
set -e
cd "$(dirname "$0")/.."
out=app/Shell/GUIDE.md
first=1
for spec in spec/[0-9][0-9]-*.md; do
  [ -n "$first" ] || printf '\n'
  first=
  cat "$spec"
done > "$out.$$" && mv "$out.$$" "$out"
