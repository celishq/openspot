#!/bin/sh
# title=Pen
# icon=pencil.tip
# detail=Draw on screen
# keywords=draw, annotate, marker, arrow, pencil, малювати, олівець
#
# button=draw
# title=Draw on screen
# icon=pencil.tip.crop.circle
here=$(cd "$(dirname "$0")" && pwd)
source="$here/pen.swift"
helper="$OPENSPOT_DATA/pen-overlay"
pidfile="$OPENSPOT_DATA/pen.pid"

running() {
  pid=$(cat "$pidfile" 2>/dev/null) && [ -n "$pid" ] && ps -p "$pid" -o comm= 2>/dev/null | grep -q 'pen-overlay$'
}

build() {
  [ -x "$helper" ] && [ ! "$source" -nt "$helper" ] && return 0
  mkdir -p "$OPENSPOT_DATA"
  printf 'progress=0.5\ntitle=Getting the pen ready\n---\n'
  swiftc=/usr/bin/swiftc
  [ -x "$swiftc" ] || swiftc=swiftc
  "$swiftc" -O -o "$helper.new" "$source" 2>"$OPENSPOT_DATA/build.log" && mv "$helper.new" "$helper"
}

case "$1" in
  draw|open)
    if running; then
      kill "$pid"
      rm -f "$pidfile"
      exit 0
    fi
    build || {
      echo "Openspot cannot build the pen. Install the Command Line Tools with \`xcode-select --install\`." >&2
      exit 1
    }
    nohup "$helper" > /dev/null 2>&1 &
    printf %s "$!" > "$pidfile"
    ;;
esac
