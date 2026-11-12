#!/bin/sh
# Writes the guide that the app bundles and that an AI reads, at the path given: GUIDE.md, then PROTOCOL.md, with each link
# between the two made a link inside the one page.
set -e
out=${1:?usage: guide.sh <output file>}
cd "$(dirname "$0")/.."
{ cat GUIDE.md; printf '\n'; cat PROTOCOL.md; } | sed -e 's/](PROTOCOL\.md#/](#/g' -e 's/](GUIDE\.md#/](#/g' -e 's/](PROTOCOL\.md)/](#openspot-protocol)/g' -e 's/](GUIDE\.md)/](#openspot-guide)/g' > "$out.$$"
mv "$out.$$" "$out"
