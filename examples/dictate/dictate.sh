#!/bin/sh
# title=Dictate
# icon=mic
# detail=Speak, and the text goes where the cursor is
# command=dictate:Dictate:mic
# read=launch
export PATH="$PATH:/opt/homebrew/bin:/usr/local/bin"
helper="$OPENSPOT_DATA/dictate"
pidfile="$OPENSPOT_DATA/dictate.pid"
model="$OPENSPOT_DATA/ggml-large-v3-turbo.bin"
loading="$OPENSPOT_DATA/download.pid"
source="$(dirname "$0")/dictate.swift"
url="https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-large-v3-turbo.bin"
size=1624555275

build() {
  [ -x "$helper" ] && [ ! "$source" -nt "$helper" ] && return 0
  mkdir -p "$OPENSPOT_DATA"
  swiftc -O -o "$helper.new" "$source" 2>/dev/null && mv "$helper.new" "$helper"
}

waiting() {
  pid=$(cat "$pidfile" 2>/dev/null) && [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null && [ ! "$helper" -nt "$pidfile" ] && [ ! "$source" -nt "$helper" ]
}

wait_here() {
  build || return 1
  [ -n "$pid" ] && kill "$pid" 2>/dev/null
  nohup "$helper" stay "$1" "$model" $2 > /dev/null 2>&1 &
  printf %s "$!" > "$pidfile"
}

download() {
  mkdir -p "$OPENSPOT_DATA"
  if ! { busy=$(cat "$loading" 2>/dev/null) && kill -0 "$busy" 2>/dev/null; }; then
    nohup sh -c 'curl -fsSL -C - -o "$1.part" "$2" && mv "$1.part" "$1"; rm -f "$3"' sh "$model" "$url" "$loading" > /dev/null 2>&1 &
    printf %s "$!" > "$loading"
  fi
  got=$(stat -f %z "$model.part" 2>/dev/null || echo 0)
  echo "toast=Openspot is downloading the Whisper model, $(( got * 100 / size ))% of 1.6 GB. Press the key again once it is done."
}

case "$1" in
  read)
    [ -z "${OPENSPOT_REASON-}" ] || waiting || (wait_here "$PPID" > /dev/null 2>&1 &)
    ;;
  dictate)
    command -v whisper-server > /dev/null || {
      echo "Openspot cannot find Whisper. Install it with \`brew install whisper-cpp\`." >&2
      exit 1
    }
    [ -f "$model" ] || { download; exit 0; }
    if waiting; then
      kill -USR1 "$pid"
      exit 0
    fi
    wait_here "$PPID" start || {
      echo "Openspot cannot build Dictate. Install the Command Line Tools with \`xcode-select --install\`." >&2
      exit 1
    }
    ;;
esac
