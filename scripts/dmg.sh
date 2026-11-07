#!/bin/sh
# Makes a disk image with a laid-out Finder window: the app on the left, Applications on the right.
# Usage: dmg.sh path/to/Openspot.app out.dmg
# The layout asks Finder, so run this in a logged-in session.
set -e
app=$1
dmg=$2
volume=Openspot
stage=$(mktemp -d)
image=$stage/image.dmg
mount=

finish() {
  [ -z "$mount" ] || hdiutil detach "$mount" -quiet 2>/dev/null || true
  rm -rf "$stage"
}
trap finish EXIT

[ -d "$app" ] || { echo "No app at $app" >&2; exit 1; }
mkdir "$stage/disk"
ditto "$app" "$stage/disk/$volume.app"
ln -s /Applications "$stage/disk/Applications"
hdiutil detach "/Volumes/$volume" -quiet 2>/dev/null || true
hdiutil create -quiet -srcfolder "$stage/disk" -volname "$volume" -fs HFS+ -format UDRW -ov "$image"
mount=$(hdiutil attach "$image" -nobrowse -noverify -noautoopen | grep "/Volumes/$volume" | tail -1 | cut -f3-)
osascript <<APPLESCRIPT
tell application "Finder"
  tell disk "$volume"
    open
    set current view of container window to icon view
    set toolbar visible of container window to false
    set statusbar visible of container window to false
    set the bounds of container window to {200, 120, 840, 480}
    set theViewOptions to the icon view options of container window
    set arrangement of theViewOptions to not arranged
    set icon size of theViewOptions to 128
    set position of item "$volume.app" of container window to {160, 170}
    set position of item "Applications" of container window to {480, 170}
    close
    open
    update without registering applications
    delay 1
    close
  end tell
end tell
APPLESCRIPT
sync
hdiutil detach "$mount" -quiet
mount=
rm -f "$dmg"
hdiutil convert -quiet "$image" -format ULFO -o "$dmg"
