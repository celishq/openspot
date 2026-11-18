#!/bin/sh
[ "$1" = show ] || exit 0
year=$(date +%Y)
day=$(date +%j | sed 's/^0*//')
days=$(date -j -f %Y-%m-%d "$year-12-31" +%j)
printf 'frame=\ngrid=year\n\nview=year\ntitle=%s\nday=%s\ndays=%s\n' "$year" "$day" "$days"
