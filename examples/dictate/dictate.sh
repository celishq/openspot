#!/bin/sh
# title=Dictate
# icon=mic
# detail=Convert speech to text
# read=sheet,1
#
# command=dictate
# title=Dictate
# icon=mic
export PATH="$PATH:/opt/homebrew/bin:/usr/local/bin"
helper="$OPENSPOT_DATA/dictate"
pidfile="$OPENSPOT_DATA/dictate.pid"
model="$OPENSPOT_DATA/ggml-large-v3-turbo.bin"
history="$OPENSPOT_DATA/history"
source="$(dirname "$0")/dictate.swift"

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

age() {
  seconds=$(( $(date +%s) - $1 / 1000 ))
  if [ "$seconds" -lt 60 ]; then echo "Just now"
  elif [ "$seconds" -lt 3600 ]; then echo "$(( seconds / 60 )) min ago"
  elif [ "$seconds" -lt 86400 ]; then echo "$(( seconds / 3600 )) h ago"
  else date -r $(( $1 / 1000 )) "+%-d %b"
  fi
}

case "$1" in
  read)
    if [ ! -f "$model" ]; then
      if [ -f "$OPENSPOT_DATA/download" ] && waiting; then
        printf 'row=whisper\ntitle=Downloading speech model\ndetail=%s%% of 1.6 GB\nicon=arrow.down.circle\nopen=Show\nclose=false\nhides=delete\npin=top\n\n' "$(cat "$OPENSPOT_DATA/download")"
      else
        printf 'row=whisper\ntitle=Download speech model\ndetail=1.6 GB\nicon=arrow.down.circle\nopen=Download\nclose=false\nhides=delete\npin=top\n\n'
      fi
    fi
    [ -s "$history" ] || { echo "search=off"; exit 0; }
    printf 'button=open\ntitle=Copy\n\nbutton=delete\ntitle=Delete\nshortcut=cmd+backspace\n\n'
    tail -r "$history" | head -n 10 | while IFS="$(printf '\t')" read -r stamp text; do
      printf 'row=%s\ntitle=%s\ndetail=%s\n\n' "$stamp" "$(printf %s "$text" | sed 's/\\/\\\\/g')" "$(age "$stamp")"
    done
    ;;
  open)
    [ -n "$2" ] || exit 0
    if [ "$2" = whisper ]; then
      if waiting; then kill -USR2 "$pid"; else wait_here "$PPID" fetch; fi
      exit 0
    fi
    grep "^$2	" "$history" | cut -f2- | tr -d '\n' | pbcopy
    echo "toast=Copied"
    ;;
  delete)
    grep -v "^$2	" "$history" > "$history.new"; mv "$history.new" "$history"
    ;;
  dictate)
    command -v whisper-server > /dev/null || {
      echo "Openspot cannot find the speech engine. Install it with \`brew install whisper-cpp\`." >&2
      exit 1
    }
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
