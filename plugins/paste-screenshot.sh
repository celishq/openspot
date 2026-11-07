#!/bin/sh
# name=Screenshot
# symbol=doc.on.clipboard.fill
# subtitle=Paste latest
# key=v
# size=small
folder=$(defaults read com.apple.screencapture location 2>/dev/null || echo "$HOME/Desktop")
case "$folder" in "~"*) folder="$HOME${folder#\~}" ;; esac
file=$(mdfind -0 -onlyin "$folder" 'kMDItemIsScreenCapture = 1 || kMDItemScreenCaptureType = "*"' | xargs -0 ls -1t 2>/dev/null | head -n 1)
image='set the clipboard to (read (POSIX file (item 1 of argv)) as'
case "$file" in
  *.png) copy="$image «class PNGf»)" ;;
  *.jpg|*.jpeg) copy="$image «class JPEG»)" ;;
  *.tif|*.tiff) copy="$image «class TIFF»)" ;;
  *.mov|*.mp4) copy="tell current application's NSPasteboard's generalPasteboard() to writeObjects:{current application's NSURL's fileURLWithPath:(item 1 of argv)}" ;;
  "") echo "No screenshot or recording found." >&2; exit 1 ;;
  *) echo "This capture type cannot be copied." >&2; exit 1 ;;
esac
if ! osascript -e 'use framework "AppKit"' -e 'use scripting additions' -e 'on run argv' -e "current application's NSPasteboard's generalPasteboard()'s clearContents()" -e "$copy" -e 'end run' "$file" 2>/dev/null; then
  echo "The capture could not be copied." >&2
  exit 1
fi
sleep 0.3
if ! osascript -e 'tell application "System Events" to keystroke "v" using command down' 2>/dev/null; then
  printf 'open=x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility\n'
  echo 'Copied. Press `⌘V`, or allow Openspot in Accessibility.' >&2
  exit 1
fi
