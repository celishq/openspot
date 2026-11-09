#!/bin/sh
# Times each keystroke of the search over copies of the real lists, in an optimized build of the Core sources.
# The first run copies the lists of this Mac into .temp/search-bench/data, and later runs reuse them, so that runs before
# and after a change read the same items. Usage: scripts/search-bench.sh [label]. Prints and keeps .temp/search-bench/<label>.txt.
set -e
cd "$(dirname "$0")/.."
out=.temp/search-bench
rm -rf "$out/build"
mkdir -p "$out/build" "$out/data"
if [ ! -s "$out/data/settings.txt" ]; then
  for name in apps settings; do
    mkdir -p "$out/plugin-data/$name"
    OPENSPOT_DATA="$PWD/$out/plugin-data/$name" sh "plugins/$name.sh" read >"$out/data/$name.txt"
  done
fi
if [ ! -s "$out/data/spots.txt" ]; then
  for file in plugins/*.sh; do
    name=$(basename "$file" .sh)
    title=$(sed -n 's/^# title=//p' "$file" | head -1)
    detail=$(sed -n 's/^# detail=//p' "$file" | head -1)
    printf 'row=%s\ntitle=%s\ndetail=%s\n\n' "$name" "${title:-$name}" "$detail"
  done >"$out/data/spots.txt"
fi
cp scripts/search-bench.swift "$out/build/main.swift"
swiftc -O -wmo -swift-version 6 -target arm64-apple-macos26.0 -module-name OpenspotCore $(find app/Core -name '*.swift') \
  "$out/build/main.swift" -o "$out/build/bench" 2>"$out/build/log" || { grep error: "$out/build/log"; exit 1; }
"$out/build/bench" "$PWD/$out/data" "$PWD/app/Keywords" | tee "$out/${1:-run}.txt"
