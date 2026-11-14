#!/bin/sh
set -e
cd "$(dirname "$0")/.."
out=.temp/film
rm -rf "$out"
mkdir -p "$out/frames"
[ -d .temp/openspot/spots ] || make dev-state >/dev/null
(cd app && xcodegen generate >/dev/null)
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project app/Openspot.xcodeproj -scheme Openspot \
  -configuration Release -derivedDataPath .temp/perf/build build -quiet >"$out/build.log" 2>&1 || { grep error: "$out/build.log"; exit 1; }
app=.temp/perf/build/Build/Products/Release/Openspot.app
codesign --force --deep -s - "$app" 2>/dev/null
swiftc -O -o "$out/window-film" scripts/window-film.swift 2>"$out/film-build.log"
slow="${SLOW:-10}"
pause=$(echo "$slow * 0.4" | bc)
OPENSPOT_CONFIG="$PWD/.temp/openspot" OPENSPOT_PROBE="$PWD/$out/probe.txt" OPENSPOT_SEEN=1 OPENSPOT_SPOT="${SPOT:-caffeinate}" \
  OPENSPOT_CYCLES=1 OPENSPOT_PAUSE="$pause" OPENSPOT_MOTION_SLOW="$slow" "$app/Contents/MacOS/Openspot" >/dev/null 2>&1 &
pid=$!
"$out/window-film" "$PWD/$out/frames" "$(echo "2.5 + $pause * 2" | bc)" "$pid"
wait "$pid" || true
command -v ffmpeg >/dev/null || exit 0
frames=$(ls "$out/frames" | sort)
press=$(echo "$frames" | awk -F. 'NR > 1 { t = $1 + 0; if (t - last > 300) print t; last = t }')
open=$(echo "$press" | tail -2 | sed -n 1p)
close=$(echo "$press" | tail -1)
tile() {
  name=$1 from=$2 to=$3
  mkdir -p "$out/$name"
  echo "$frames" | awk -F. -v a="$from" -v b="$to" '$1 + 0 >= a && $1 + 0 < b' > "$out/$name.list"
  count=$(wc -l < "$out/$name.list")
  step=$(( (count + 20) / 21 ))
  awk -v s="$step" 'NR % s == 1 || s == 1' "$out/$name.list" | head -21 | while read -r f; do
    ffmpeg -loglevel error -y -i "$out/frames/$f" -vf "crop=iw*0.82:ih*0.89:iw*0.09:ih*0.08,scale=iw/2:-1,pad=iw+6:ih+6:3:3:red" "$out/$name/$f"
  done
  ffmpeg -loglevel error -y -pattern_type glob -i "$out/$name/*.png" -vf "tile=7x3" -frames:v 1 "$out/$name.png"
}
tile open "$open" "$close"
tile close "$close" 999999
echo "$out/open.png $out/close.png"
