#!/bin/sh
# Builds a Release app and saves pictures of the actions menu into .temp/shots: at a small card on each side, a wide card,
# a long menu and its search, a row of SPOT's list (apps by default), and a search result. The field's pictures are at 2x.
set -e
cd "$(dirname "$0")/.."
out=.temp/shots
rm -rf "$out"
mkdir -p "$out"
[ -d .temp/openspot/spots ] || make dev-state >/dev/null
(cd app && xcodegen generate >/dev/null)
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project app/Openspot.xcodeproj -scheme Openspot \
  -configuration Release -derivedDataPath .temp/perf/build build -quiet >"$out/build.log" 2>&1 || { grep error: "$out/build.log"; exit 1; }
app=.temp/perf/build/Build/Products/Release/Openspot.app
codesign --force --deep -s - "$app" 2>/dev/null
OPENSPOT_CONFIG="$PWD/.temp/openspot" OPENSPOT_PROBE="$PWD/$out/probe.txt" OPENSPOT_ACTION=menu OPENSPOT_SHOTS="$PWD/$out" \
  OPENSPOT_SEEN=1 OPENSPOT_SPOT="${SPOT:-apps}" "$app/Contents/MacOS/Openspot" >"$out/run.log" 2>&1
ls "$out"/*.png
