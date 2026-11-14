#!/bin/sh
set -e
cd "$(dirname "$0")/.."
out=.temp/perf
rm -rf "$out/runs"
mkdir -p "$out/runs"
[ -d .temp/openspot/spots ] || make dev-state >/dev/null
(cd app && xcodegen generate >/dev/null)
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project app/Openspot.xcodeproj -scheme Openspot \
  -configuration Release -derivedDataPath "$out/build" build -quiet >"$out/build.log" 2>&1 || { grep error: "$out/build.log"; exit 1; }
app="$out/build/Build/Products/Release/Openspot.app"
codesign --force --deep -s - "$app" 2>/dev/null
caffeinate -d -u -w $$ &
for run in $(seq "${1:-3}"); do
  OPENSPOT_CONFIG="$PWD/.temp/openspot" OPENSPOT_PROBE="$PWD/$out/runs/$run.txt" OPENSPOT_SPOT="$SPOT" OPENSPOT_ACTION="$ACTION" \
    OPENSPOT_CYCLES="${CYCLES:-20}" OPENSPOT_PAUSE="${PAUSE:-0.15}" OPENSPOT_TEXT="$TEXT" "$app/Contents/MacOS/Openspot" >/dev/null 2>&1
  head -1 "$out/runs/$run.txt"
done
median=$(for run in "$out"/runs/*.txt; do head -1 "$run" | sed -E 's/.*dropped ([0-9]+).*/\1/'; done | sort -n | awk '{ v[NR] = $1 } END { print v[int((NR + 1) / 2)] }')
echo "median dropped $median, budget ${BUDGET:-140}"
[ "$median" -le "${BUDGET:-140}" ]
