#!/bin/sh
# name=Screenshot
# symbol=doc.on.clipboard.fill
# subtitle=Paste latest
# key=v
# size=small
folder=$(defaults read com.apple.screencapture location 2>/dev/null || echo "$HOME/Desktop")
case "$folder" in "~"*) folder="$HOME${folder#\~}" ;; esac
file=$(mdfind -0 -onlyin "$folder" 'kMDItemIsScreenCapture = 1 || kMDItemScreenCaptureType = "*"' | xargs -0 ls -1t 2>/dev/null | head -n 1)
[ -n "$file" ] || { echo "Openspot cannot find a screenshot or a screen recording." >&2; exit 1; }
exec openspot clipboard paste "$file"
