#!/bin/sh
# Joins the specs 00 to 99 into the one guide that the app bundles and that an AI reads, at the path given.
set -e
out=${1:?usage: guide.sh <output file>}
cd "$(dirname "$0")/.."
first=1
for spec in spec/[0-9][0-9]-*.md; do
  [ -n "$first" ] || printf '\n'
  first=
  cat "$spec"
done > "$out.$$" && mv "$out.$$" "$out"
