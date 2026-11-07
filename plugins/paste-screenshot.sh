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
  "") echo "Openspot cannot find a screenshot or a screen recording." >&2; exit 1 ;;
  *) echo "Openspot cannot copy this kind of file. It copies PNG, JPEG, TIFF, MOV and MP4." >&2; exit 1 ;;
esac
if ! osascript -e 'use framework "AppKit"' -e 'use scripting additions' -e 'on run argv' -e "current application's NSPasteboard's generalPasteboard()'s clearContents()" -e "$copy" -e 'end run' "$file" 2>/dev/null; then
  echo "Openspot could not copy the capture. Try again." >&2
  exit 1
fi
sleep 0.3
if ! osascript -e 'tell application "System Events" to keystroke "v" using command down' 2>/dev/null; then
  printf 'open=x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility\n'
  echo 'Copied, but Openspot cannot paste. Press `⌘V`, or allow Openspot in Accessibility.' >&2
  exit 1
fi
