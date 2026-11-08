#!/bin/sh
# name=Liquid battery
# icon=battery.100
# subtitle=The battery as a liquid, drawn by a Metal shader
# read=panel
# size=strip
# view=battery.swift
[ "$1" = read ] || exit 0
line=$(pmset -g batt | grep -E '[0-9]+%')
if [ -z "$line" ]; then
  printf 'view=liquid\ntitle=–\ndetail=No battery\n'
  exit 0
fi
percent=$(printf '%s' "$line" | grep -oE '[0-9]+%' | tr -d '%')
left=$(printf '%s' "$line" | grep -oE '[0-9]+:[0-9]+' | head -1)
case "$line" in
  *discharging*) state=discharging; detail="${left:+$left left}" ;;
  *charged*) state=charged; detail=Full ;;
  *charging*) state=charging; detail=Charging ;;
  *) state=discharging; detail="" ;;
esac
printf 'view=liquid\ntitle=%s\nstate=%s\ndetail=%s\n' "$percent" "$state" "${detail:-On battery}"
