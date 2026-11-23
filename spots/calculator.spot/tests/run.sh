#!/bin/sh
# Builds the tests of Calculator, which load calculator.js into JavaScriptCore, and runs them. `make verify` runs each
# `tests/run.sh` of a spot.
set -e
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
spot=$(cd "$(dirname "$0")/.." && pwd)
out=$(mktemp -d)
trap 'rm -rf "$out"' EXIT
platform=$(xcrun --sdk macosx --show-sdk-platform-path)
mkdir -p "$out/Calculator.xctest/Contents/MacOS"
xcrun swiftc -module-name CalculatorTests -F "$platform/Developer/Library/Frameworks" -I "$platform/Developer/usr/lib" \
  -L "$platform/Developer/usr/lib" -emit-library -o "$out/Calculator.xctest/Contents/MacOS/Calculator" "$spot"/tests/*.swift
CALCULATOR_SPOT="$spot" xcrun xctest "$out/Calculator.xctest"
