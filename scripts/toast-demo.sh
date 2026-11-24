#!/bin/sh
set -e
cd "$(dirname "$0")/.."
mkdir -p .temp
[ -d .temp/openspot/spots ] || make dev-state >/dev/null
folder=.temp/openspot/spots/toast-demo.spot
rm -rf "$folder"
mkdir -p "$folder"
printf 'title = "Toast Demo"\nicon = "bell"\n\n[actions.upload]\ntitle = "Show a kept toast"\n\n[actions.done]\n' > "$folder/spot.toml"
cat > "$folder/toast-demo.sh" <<'SPOT'
#!/bin/sh
case "$1" in
  show) printf 'item=upload\ntitle=Show a kept toast\n' ;;
  upload)
    printf 'toast=upload\ntitle=Uploading 3 files.\nkeep=true\naction=done\n' | openspot toast
    sleep 2
    printf 'toast=upload\ntitle=Uploaded 2 of 3 files. Click to finish.\nkeep=true\naction=done\n' | openspot toast
    ;;
  done) openspot toast 'The click ran the action `done`.' ;;
esac
SPOT
chmod +x "$folder/toast-demo.sh"
(cd app && xcodegen generate >/dev/null)
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project app/Openspot.xcodeproj -scheme Openspot -configuration Debug \
  -destination 'platform=macOS' -derivedDataPath .temp/dd build -quiet >.temp/toast-demo.log 2>&1 || { grep error: .temp/toast-demo.log; exit 1; }
openspot=.temp/dd/Build/Products/Debug/Openspot.app/Contents/Helpers/openspot
"$openspot" toast 'Saved `Invoice.pdf` to Downloads.'
sleep 0.6
"$openspot" toast 'Copied the link.'
sleep 0.6
"$openspot" spot run toast-demo upload >/dev/null
sleep 0.6
"$openspot" toast 'A fourth toast takes the place of the oldest that shows.'
echo "Toasts went to the Debug app. Hover over them to hold them, and click Uploaded to run its action. Quit it with $openspot app quit."
