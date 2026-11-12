#!/bin/sh
# Writes the guide that the app bundles and that an AI reads, at the path given: the protocol as it is.
set -e
out=${1:?usage: guide.sh <output file>}
cd "$(dirname "$0")/.."
cp spec/protocol.md "$out.$$" && mv "$out.$$" "$out"
