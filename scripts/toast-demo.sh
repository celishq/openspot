#!/bin/sh
set -e
cd "$(dirname "$0")/.."
mkdir -p .temp
[ -d .temp/openspot/spots ] || make dev-state >/dev/null
(cd app && xcodegen generate >/dev/null)
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project app/Openspot.xcodeproj -scheme Openspot -configuration Debug \
  -destination 'platform=macOS' -derivedDataPath .temp/dd build -quiet >.temp/toast-demo.log 2>&1 || { grep error: .temp/toast-demo.log; exit 1; }
openspot=.temp/dd/Build/Products/Debug/Openspot.app/Contents/Helpers/openspot
"$openspot" toast 'Saved `Invoice.pdf` to Downloads.'
sleep 0.6
"$openspot" toast 'Copied the link.'
sleep 0.6
"$openspot" toast 'Openspot cannot find a screenshot. Take one with `⇧⌘4`, then try again.'
sleep 0.6
"$openspot" toast 'A fourth toast takes the place of the oldest.'
echo "Four toasts went to the Debug app; three show at once. Hover over them to keep them. Quit it with $openspot app quit."
