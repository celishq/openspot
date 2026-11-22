#!/bin/sh
printf 'button=copy\ntitle=Copy\nshortcut=cmd+return\n\n'
printf 'button=reveal\ntitle=Show in Finder\nshortcut=cmd+r\n\n'
printf 'button=edit\ntitle=Edit\nshortcut=cmd+e\nform=true\nclose=false\n\n'
printf 'button=delete\ntitle=Delete\nshortcut=cmd+backspace\nconfirm=Press again to delete\nclose=false\n\n'
printf 'button=new\ntitle=New link\nshortcut=cmd+n\nscope=spot\nform=true\nclose=false\n\n'
for link in 'calendar:Team calendar:calendar.example.com' 'docs:Project docs:docs.example.com' 'mail:Mail:mail.example.com' 'tracker:Issue tracker:tracker.example.com' 'weather:Weather:weather.com'; do
  printf '%s\n' "$link" | awk -F: '{ printf "item=%s\ntitle=%s\ndetail=%s\nhides=reveal\nicon=link\n\n", $1, $2, $3 }'
done
icons=/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources
printf 'item=downloads\ntitle=Downloads\ndetail=~/Downloads\nicon=%s/DownloadsFolder.icns\n\n' "$icons"
printf 'item=screenshots\ntitle=Screenshots\ndetail=~/Desktop\nicon=%s/DesktopFolderIcon.icns\n' "$icons"
