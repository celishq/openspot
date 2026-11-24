#!/bin/sh
printf 'button=reveal\ntitle=Show in Finder\nshortcut=cmd+return\n\n'
printf 'button=copy\ntitle=Copy path\nshortcut=cmd+shift+c\n\n'
for file in 'Documents/Report.pages' 'Documents/Work/Report 2026.key' 'Desktop/report-draft.txt' 'Documents/Taxes/Report Q3.numbers' 'Downloads/report-summary.rtf' 'Documents/Work/Report notes.md'; do
  printf 'item=/Users/you/%s\ntitle=%s\ndetail=~/%s\nicon=/Users/you/%s\n\n' "$file" "${file##*/}" "${file%/*}" "$file"
done
