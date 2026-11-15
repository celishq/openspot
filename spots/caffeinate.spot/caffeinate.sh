#!/bin/sh
# icon=cup.and.saucer.fill
# detail=Keep the Mac awake
# on=panel.open
# mode=stay
# offers=card

# One process answers every call. The call that turns Caffeinate on stays open while `caffeinate` runs, so Openspot
# keeps this process until it ends, and a quit of Openspot ends `caffeinate` too. Nothing is written to disk.
held=
watcher=
until=0

awake() {
  [ -n "$watcher" ] && kill -0 "$watcher" 2>/dev/null
}

# Prints how long the Mac stays awake, which the card shows while the call that turned it on runs.
left() {
  if [ "$until" = 0 ]; then
    echo "Until off"
    return
  fi
  minutes=$(( (until - $(date +%s) + 59) / 60 ))
  [ "$minutes" -gt 0 ] || minutes=1
  if [ "$minutes" -ge 60 ]; then
    echo "$(( minutes / 60 ))h $(( minutes % 60 ))m left"
  else
    echo "${minutes}m left"
  fi
}

# Prints the rows of the sheet, with Turn off first while the Mac is kept awake.
sheet() {
  printf 'recents=false\n\n'
  printf 'button=open\ntitle=Select\n\n'
  awake && printf 'row=off\ntitle=Turn off\n\n'
  printf 'row=1800\ntitle=30 minutes\n\n'
  printf 'row=3600\ntitle=1 hour\n\n'
  printf 'row=7200\ntitle=2 hours\n\n'
  printf 'row=14400\ntitle=4 hours\n\n'
  printf 'row=28800\ntitle=8 hours\n\n'
  printf 'row=0\ntitle=Until turned off\n'
}

# Runs `caffeinate` for that many seconds, or until it is stopped, in a watcher that ends the call when it ends by itself.
hold() {
  held=$1
  if [ "$2" = 0 ]; then until=0; else until=$(( $(date +%s) + $2 )); fi
  (
    awake=
    trap '[ -z "$awake" ] || kill "$awake" 2>/dev/null; exit 0' TERM
    if [ "$2" = 0 ]; then caffeinate -di & else caffeinate -di -t "$2" & fi
    awake=$!
    wait "$awake"
    watcher=
    printf 'end=%s\n---\n%s\n---\n' "$1" "$(sheet)"
  ) &
  watcher=$!
}

# Stops `caffeinate`, and sets `ended` to the frame that ends the call that turned it on.
release() {
  ended=
  awake || { watcher=; held=; return 0; }
  kill "$watcher" 2>/dev/null
  wait "$watcher" 2>/dev/null
  watcher=
  ended="end=$held
---
"
  held=
}

toast() {
  minutes=$(( $1 / 60 ))
  if [ "$1" = 0 ]; then echo "Caffeinate is on until you turn it off"
  elif [ "$minutes" -ge 120 ]; then echo "Caffeinate is on for $(( minutes / 60 )) hours"
  elif [ "$minutes" -eq 60 ]; then echo "Caffeinate is on for 1 hour"
  elif [ "$minutes" -eq 1 ]; then echo "Caffeinate is on for 1 minute"
  else echo "Caffeinate is on for $minutes minutes"
  fi
}

# Answers one call. Each answer is one write, so that it never mixes with the frame of a watcher that ends. The call
# that turns Caffeinate on prints the rows before it starts, and then only a head with the time left, which the card
# shows while that call runs: a call that prints rows is not shown as running.
serve() {
  case "$1 $2" in
    'open off')
      release
      printf '%scall=%s\n---\ntoast=Caffeinate is off\n%s\n---\nend=%s\n---\n' "$ended" "$call" "$(sheet)" "$call"
      ;;
    open\ [0-9]*)
      release
      hold "$call" "$2"
      printf '%s%s\n---\ncall=%s\n---\ntoast=%s\ndetail=%s\n---\n' "$ended" "$(sheet)" "$call" "$(toast "$2")" "$(left)"
      ;;
    *)
      now=
      awake && now="call=$held
---
detail=$(left)
---
"
      printf 'call=%s\n---\n%s\n---\nend=%s\n---\n%s' "$call" "$(sheet)" "$call" "$now"
      ;;
  esac
}

call=
while IFS= read -r line; do
  case $line in
    call=*) call=${line#call=}; set -- ;;
    arg=*) set -- "$@" "${line#arg=}" ;;
    stop=*)
      if [ "${line#stop=}" = "$held" ]; then
        release
        printf '%s%s\n---\n' "$ended" "$(sheet)"
      fi
      ;;
    '')
      [ -z "$call" ] || serve "$@"
      call=
      ;;
  esac
done
release
