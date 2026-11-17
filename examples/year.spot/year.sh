#!/bin/sh
# title=Year
# icon=calendar
# detail=Each day of this year as a square
# on=panel.open
# view=year.swift
# offers=card
[ "$1" = read ] || exit 0
year=$(date +%Y)
day=$(date +%j | sed 's/^0*//')
days=$(date -j -f %Y-%m-%d "$year-12-31" +%j)
printf 'view=year\ntitle=%s\nleft=%s\nday=%s\ndays=%s\n' "$year" "$((days - day))" "$day" "$days"
