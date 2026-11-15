#!/bin/sh
# title=Year
# icon=calendar
# detail=The months of this year
# on=panel.open
# view=year.swift
# offers=card
[ "$1" = read ] || exit 0
year=$(date +%Y)
day=$(date +%j | sed 's/^0*//')
days=$(date -j -f %Y-%m-%d "$year-12-31" +%j)
month=$(date +%m | sed 's/^0*//')
date=$(date +%d | sed 's/^0*//')
length=$(date -j -v1d -v+1m -v-1d +%d)
printf 'view=year\ntitle=%s\nleft=%s\nmonth=%s\nprogress=%s\n' "$year" "$((days - day))" "$month" "$(awk "BEGIN { print $date / $length }")"
