#!/bin/sh
# Builds the tests of Draw with its model and its app, and runs them. `make verify` runs each `tests/run.sh` of a spot.
# Each test writes only under the folder in DRAW_TESTS, which goes when the run ends.
set -e
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
spot=$(cd "$(dirname "$0")/.." && pwd)
out=$(mktemp -d)
trap 'rm -rf "$out"' EXIT
platform=$(xcrun --sdk macosx --show-sdk-platform-path)
mkdir -p "$out/Draw.xctest/Contents/MacOS" "$out/work"
xcrun swiftc -module-name DrawTests -F "$platform/Developer/Library/Frameworks" -I "$platform/Developer/usr/lib" \
  -L "$platform/Developer/usr/lib" -emit-library -o "$out/Draw.xctest/Contents/MacOS/Draw" \
  "$spot"/model/*.swift "$spot"/app/*.swift "$spot"/tests/*.swift
DRAW_TESTS="$out/work" DRAW_SPOT="$spot" xcrun xctest "$out/Draw.xctest"
