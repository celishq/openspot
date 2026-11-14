#!/bin/sh
# title=Grid
# icon=square.grid.3x3
# detail=Drag over a grid to place the front window
# on=panel.open
# offers=card
helper="$OPENSPOT_DATA/grid"
pidfile="$OPENSPOT_DATA/grid.pid"
source="$(dirname "$0")/grid.swift"

build() {
  [ -x "$helper" ] && [ ! "$source" -nt "$helper" ] && return 0
  mkdir -p "$OPENSPOT_DATA"
  swiftc -O -o "$helper.new" "$source" 2>/dev/null && mv "$helper.new" "$helper"
}

waiting() {
  pid=$(cat "$pidfile" 2>/dev/null) && [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null && [ ! "$helper" -nt "$pidfile" ] && [ ! "$source" -nt "$helper" ]
}

ended() {
  [ -n "$1" ] && kill "$1" 2>/dev/null || return 0
  tries=0
  while kill -0 "$1" 2>/dev/null && [ "$tries" -lt 40 ]; do sleep 0.05; tries=$((tries + 1)); done
}

wait_here() {
  build || return 1
  ended "$pid"
  nohup "$helper" stay "$1" > /dev/null 2>&1 &
}

case "$1" in
  read)
    [ -z "${OPENSPOT_REASON-}" ] || waiting || (wait_here "$PPID" > /dev/null 2>&1 &)
    ;;
  open)
    if waiting; then
      kill -USR1 "$pid"
      exit 0
    fi
    build || {
      echo "Openspot cannot build the grid. Install the Command Line Tools with \`xcode-select --install\`." >&2
      exit 1
    }
    pick=$("$helper") || exit 1
    [ -z "$pick" ] && exit 0
    moved=$(openspot window move "$pick") && exit 0
    link=$(printf '%s\n' "$moved" | sed -n 's/^link=//p' | head -n 1)
    [ -n "$link" ] || exit 1
    open "$link"
    ;;
esac
