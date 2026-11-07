#!/bin/sh
# Builds a Release app and times the frames while a sheet opens and closes again and again.
# The panel stays almost clear and takes no focus, so the Mac stays usable. Each run prints one line.
# Usage: scripts/motion-perf.sh [runs]. SPOT, CYCLES and PAUSE pass to the probe.
set -e
cd "$(dirname "$0")/.."
out=.temp/perf
rm -rf "$out/runs"
mkdir -p "$out/runs"
[ -d .temp/openspot/plugins ] || make dev-state >/dev/null
(cd app && xcodegen generate >/dev/null)
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project app/Openspot.xcodeproj -scheme Openspot \
  -configuration Release -derivedDataPath "$out/build" build -quiet >"$out/build.log" 2>&1 || { grep error: "$out/build.log"; exit 1; }
app="$out/build/Build/Products/Release/Openspot.app"
codesign --force --deep -s - "$app" 2>/dev/null
for run in $(seq "${1:-3}"); do
  OPENSPOT_CONFIG="$PWD/.temp/openspot" OPENSPOT_PROBE="$PWD/$out/runs/$run.txt" OPENSPOT_SPOT="$SPOT" \
    OPENSPOT_CYCLES="${CYCLES:-20}" OPENSPOT_PAUSE="${PAUSE:-0.15}" "$app/Contents/MacOS/Openspot" >/dev/null 2>&1
  head -1 "$out/runs/$run.txt"
done
