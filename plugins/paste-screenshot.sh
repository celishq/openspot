#!/bin/sh
# title=Paste latest screenshot
# icon=doc.on.clipboard.fill
# detail=From the screenshot folder
# size=small
folder() {
  dir=$(defaults read com.apple.screencapture "$1" 2>/dev/null || defaults read com.apple.screencapture location 2>/dev/null || echo "$HOME/Desktop")
  case "$dir" in "~"*) dir="$HOME${dir#\~}" ;; esac
  echo "$dir"
}
file=$(find "$(folder location-screenshot)" "$(folder location-screenrecording)" -maxdepth 1 -type f -exec stat -f '%m %N' {} + 2>/dev/null | sort -rn | cut -d ' ' -f 2- | while IFS= read -r f; do
  xattr -p com.apple.metadata:kMDItemScreenCaptureType "$f" >/dev/null 2>&1 && { echo "$f"; break; }
done)
[ -n "$file" ] || { echo "Openspot cannot find a screenshot or a screen recording." >&2; exit 1; }
openspot clipboard copy "$file" && exec openspot clipboard paste
