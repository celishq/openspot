#!/bin/sh
[ "$1" = show ] || exit 0
year=$(date +%Y)
day=$(date +%j | sed 's/^0*//')
days=$(date -j -f %Y-%m-%d "$year-12-31" +%j)
printf 'frame=\nclass=relative card:relative\n\nyear=year\nclass=absolute inset-0\ntitle=%s\nday=%s\ndays=%s\n' "$year" "$day" "$days"
