#!/bin/sh
# Builds the tests of Agents with its sources, and runs them. `make verify` runs each `tests/run.sh` of a spot.
# Each test writes only under the folder in AGENTS_TESTS, which goes when the run ends.
set -e
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
spot=$(cd "$(dirname "$0")/.." && pwd)
out=$(mktemp -d)
trap 'rm -rf "$out"' EXIT
platform=$(xcrun --sdk macosx --show-sdk-platform-path)
mkdir -p "$out/Agents.xctest/Contents/MacOS" "$out/work"
xcrun swiftc -module-name AgentsTests -F "$platform/Developer/Library/Frameworks" -I "$platform/Developer/usr/lib" \
  -L "$platform/Developer/usr/lib" -emit-library -o "$out/Agents.xctest/Contents/MacOS/Agents" \
  "$spot"/agents/*.swift "$spot"/tests/*.swift
AGENTS_TESTS="$out/work" xcrun xctest "$out/Agents.xctest"
