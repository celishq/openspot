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
    OPENSPOT_SH="$PWD/app/Shell/openspot.sh" OPENSPOT_DATA="$PWD/$out/plugin-data/$name" sh "spots/$name.spot/$name.sh" read >"$out/data/$name.txt"
  done
fi
if [ ! -s "$out/data/spots.txt" ]; then
  for file in spots/*.spot/*.sh; do
    case $file in spots/openspot.spot/*) continue ;; esac
    name=$(basename "$file" .sh)
    title=$(sed -n 's/^# title=//p' "$file" | head -1)
    detail=$(sed -n 's/^# detail=//p' "$file" | head -1)
    printf 'row=%s\ntitle=%s\ndetail=%s\n\n' "$name" "${title:-$name}" "$detail"
  done >"$out/data/spots.txt"
fi
package="$out/package"
mkdir -p "$package/Sources/OpenspotCore"
ln -sfn "$PWD/app/Core" "$package/Sources/OpenspotCore/Core"
for file in CommandKind SocketPath; do ln -sfn "$PWD/app/Client/$file.swift" "$package/Sources/OpenspotCore/$file.swift"; done
cp scripts/search-bench.swift "$package/Sources/OpenspotCore/main.swift"
cat > "$package/Package.swift" <<'SWIFT'
// swift-tools-version: 6.1
import PackageDescription

let package = Package(
    name: "SearchBench",
    platforms: [.macOS("26.0")],
    dependencies: [.package(url: "https://github.com/21-DOT-DEV/swift-secp256k1", exact: "0.24.0")],
    targets: [.executableTarget(name: "OpenspotCore", dependencies: [.product(name: "P256K", package: "swift-secp256k1")])]
)
SWIFT
swift build -c release --package-path "$package" >"$out/build/log" 2>&1 || { grep error: "$out/build/log"; exit 1; }
"$package/.build/release/OpenspotCore" "$PWD/$out/data" "$PWD/app/Keywords" | tee "$out/${1:-run}.txt"
