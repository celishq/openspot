#!/bin/sh
# name=Paste latest screenshot
# symbol=doc.on.clipboard.fill
# subtitle=From the screenshot folder
# key=v
# size=small
folder=$(defaults read com.apple.screencapture location 2>/dev/null || echo "$HOME/Desktop")
case "$folder" in "~"*) folder="$HOME${folder#\~}" ;; esac
file=$(mdfind -0 -onlyin "$folder" 'kMDItemIsScreenCapture = 1' | xargs -0 ls -1t 2>/dev/null | head -n 1)
case "$file" in
  *.png) class='«class PNGf»' ;;
  *.jpg|*.jpeg) class='«class JPEG»' ;;
  *.tif|*.tiff) class='«class TIFF»' ;;
  "") echo "No screenshot found." >&2; exit 1 ;;
  *) echo "This screenshot type cannot be copied." >&2; exit 1 ;;
esac
if ! osascript -e 'on run argv' -e "set the clipboard to (read (POSIX file (item 1 of argv)) as $class)" -e 'end run' "$file" 2>/dev/null; then
  echo "The screenshot could not be copied." >&2
  exit 1
fi
sleep 0.3
if ! osascript -e 'tell application "System Events" to keystroke "v" using command down' 2>/dev/null; then
  echo "Copied. Press Command-V, or allow Openspot in Accessibility." >&2
  exit 1
fi
