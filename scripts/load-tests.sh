#!/bin/sh
cd "$(dirname "$0")/.."
out=.temp/load
rm -rf "$out"
mkdir -p "$out"
runs=${1:-3}
only=
for name in $2; do only="$only -only-testing:OpenspotTests/$name"; done
(cd app && xcodegen generate >/dev/null)
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
project="-project app/Openspot.xcodeproj -scheme Openspot -destination platform=macOS -derivedDataPath $out/build"
xcodebuild $project build-for-testing >"$out/build.log" 2>&1 || { grep error: "$out/build.log"; exit 1; }
for _ in $(seq "$(sysctl -n hw.ncpu)"); do yes >/dev/null & done
trap 'kill $(jobs -p) 2>/dev/null' EXIT
passed=0
for run in $(seq "$runs"); do
  if xcodebuild $project -test-timeouts-enabled YES -default-test-execution-time-allowance 120 \
    -maximum-test-execution-time-allowance 300 $only test-without-building >"$out/$run.log" 2>&1; then
    passed=$((passed + 1))
    echo "run $run passed"
  else
    echo "run $run failed:"
    grep -E "^Test case '.*' failed" "$out/$run.log" | sed -E "s/^Test case '([^']*)'.*/  \1/" | sort -u
  fi
done
echo "$passed of $runs runs passed beside $(sysctl -n hw.ncpu) busy cores; logs in $out"
[ "$passed" -eq "$runs" ]
