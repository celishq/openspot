#!/bin/sh
# Writes the guide that the app bundles and that an AI reads, at the path given: the protocol up to its part for
# maintainers.
set -e
out=${1:?usage: guide.sh <output file>}
cd "$(dirname "$0")/.."
sed '/^## Maintaining this protocol$/,$d' spec/protocol.md > "$out.$$" && mv "$out.$$" "$out"
