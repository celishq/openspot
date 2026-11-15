#!/bin/sh
printf 'button=open\ntitle=Run\n\n'
printf 'button=clipboard\ntitle=Run with clipboard\nshortcut=cmd+return\nclose=true\n\n'
printf 'button=edit\ntitle=Open in Shortcuts\nshortcut=cmd+e\nclose=true\n\n'
for name in 'Make GIF' 'Start focus' 'Text last image' 'Add to reading list' 'Shorten link' 'Convert to PDF' 'Resize images'; do
  printf 'row=%s\ntitle=%s\nicon=/System/Applications/Shortcuts.app\n' "$name" "$name"
  case $name in 'Convert to PDF' | 'Resize images') printf 'parent=Files\n' ;; esac
  printf '\n'
done
