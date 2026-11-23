#!/bin/sh
set -e
out=${1:?usage: guide.sh <output file>}
cd "$(dirname "$0")/.."
{ cat GUIDE.md; printf '\n'; cat PROTOCOL.md; printf '\n'; cat USING.md; } | sed -e 's/](PROTOCOL\.md#/](#/g' -e 's/](GUIDE\.md#/](#/g' -e 's/](PROTOCOL\.md)/](#openspot-protocol)/g' -e 's/](GUIDE\.md)/](#openspot-guide)/g' -e 's/](USING\.md#/](#/g' -e 's/](USING\.md)/](#use-openspot)/g' > "$out.$$"
mv "$out.$$" "$out"
