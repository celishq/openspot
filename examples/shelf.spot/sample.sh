#!/bin/sh
printf 'recents=false\n\n'
printf 'button=reveal\ntitle=Show in Finder\nshortcut=cmd+return\n\n'
printf 'button=remove\ntitle=Remove from Shelf\nshortcut=cmd+backspace\n\n'
printf 'button=clear\ntitle=Clear Shelf\nscope=spot\n'
for file in 'Desktop/Launch plan.pdf' 'Downloads/brand-assets.zip' 'Documents/Budget 2026.numbers' 'Pictures/Screenshots/onboarding-step-2.png' 'Documents/Contracts/Lease renewal.pdf'; do
  printf '\nrow=/Users/you/%s\ntitle=%s\ndetail=~/%s\nicon=/Users/you/%s\nfile=/Users/you/%s\n' "$file" "${file##*/}" "${file%/*}" "$file" "$file"
done
