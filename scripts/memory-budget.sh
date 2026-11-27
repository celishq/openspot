#!/bin/sh
set -e
cd "$(dirname "$0")/.."
out=.temp/memory
rm -rf "$out/runs"
mkdir -p "$out/runs"
[ -d .temp/openspot/spots ] || make dev-state >/dev/null
(cd app && xcodegen generate >/dev/null)
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project app/Openspot.xcodeproj -scheme Openspot \
  -configuration Release SWIFT_ACTIVE_COMPILATION_CONDITIONS=OPENSPOT_TOOLS -derivedDataPath "$out/build" build -quiet >"$out/build.log" 2>&1 || { grep error: "$out/build.log"; exit 1; }
app="$out/build/Build/Products/Release/Openspot.app"
codesign --force --deep -s - "$app" 2>/dev/null
config="$PWD/.temp/openspot"
for run in $(seq "${1:-1}"); do
  "$app/Contents/MacOS/Openspot" --config "$config" --probe "$PWD/$out/runs/$run.txt" --probe-action memory >/dev/null 2>&1
done
for run in "$out"/runs/*.txt; do awk -F '\t' '{ printf "%-18s %7s MB\n", $1, $2 }' "$run"; done
closed=$(for run in "$out"/runs/*.txt; do tail -1 "$run" | cut -f2; done | sort -n | awk '{ v[NR] = $1 } END { print v[int((NR + 1) / 2)] }')
echo "after the last close $closed MB, budget ${BUDGET:-85} MB"
awk -v closed="$closed" -v budget="${BUDGET:-85}" 'BEGIN { exit !(closed <= budget) }'
