#!/bin/sh
set -e
cd "$(dirname "$0")/.."
out=.temp/shots
rm -rf "$out"
mkdir -p "$out"
[ -d .temp/openspot/spots ] || make dev-state >/dev/null
(cd app && xcodegen generate >/dev/null)
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project app/Openspot.xcodeproj -scheme Openspot \
  -configuration Release SWIFT_ACTIVE_COMPILATION_CONDITIONS=OPENSPOT_TOOLS -derivedDataPath .temp/perf/build build -quiet >"$out/build.log" 2>&1 || { grep error: "$out/build.log"; exit 1; }
app=.temp/perf/build/Build/Products/Release/Openspot.app
codesign --force --deep -s - "$app" 2>/dev/null
"$app/Contents/MacOS/Openspot" --config "$PWD/.temp/openspot" --probe "$PWD/$out/probe.txt" --probe-action "${ACTION:-menu}" --probe-text "$TEXT" \
  --shots "$PWD/$out" --seen --probe-spot "${SPOT:-apps}" >"$out/run.log" 2>&1
ls "$out"/*.png
