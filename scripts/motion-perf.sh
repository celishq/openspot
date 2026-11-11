#!/bin/sh
# Builds a Release app and times the frames while a sheet opens and closes again and again.
# The panel stays almost clear and takes no focus, so the Mac stays usable. Each run prints one line.
# Usage: scripts/motion-perf.sh [runs]. SPOT, ACTION (arrows, typing, pick, drag, edit, or panel with a PAUSE over 5 s), CYCLES and PAUSE pass to the probe. It fails when the median of dropped
# frames is over BUDGET (140 for the 40 motions of a run), and keeps the display awake while it runs.
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
caffeinate -d -u -w $$ &
for run in $(seq "${1:-3}"); do
  OPENSPOT_CONFIG="$PWD/.temp/openspot" OPENSPOT_PROBE="$PWD/$out/runs/$run.txt" OPENSPOT_SPOT="$SPOT" OPENSPOT_ACTION="$ACTION" \
    OPENSPOT_CYCLES="${CYCLES:-20}" OPENSPOT_PAUSE="${PAUSE:-0.15}" "$app/Contents/MacOS/Openspot" >/dev/null 2>&1
  head -1 "$out/runs/$run.txt"
done
median=$(for run in "$out"/runs/*.txt; do head -1 "$run" | sed -E 's/.*dropped ([0-9]+).*/\1/'; done | sort -n | awk '{ v[NR] = $1 } END { print v[int((NR + 1) / 2)] }')
echo "median dropped $median, budget ${BUDGET:-140}"
[ "$median" -le "${BUDGET:-140}" ]
