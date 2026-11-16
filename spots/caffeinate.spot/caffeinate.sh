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
secs=

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

# Prints the row of one duration. The row of the duration that runs carries the id of its call, so that a pick of it
# is a new call that starts it again, and not a second press that would stop it.
duration() {
  if awake && [ "$1" = "$secs" ]; then
    printf 'row=%s.%s\ntitle=%s\n' "$1" "$held" "$2"
  else
    printf 'row=%s\ntitle=%s\n' "$1" "$2"
  fi
}

# Prints the rows of the sheet, with Turn off first while the Mac is kept awake.
sheet() {
  printf 'recents=false\n\n'
  printf 'button=open\ntitle=Select\n\n'
  printf 'button=start\ntitle=Keep awake for…\nscope=spot\nform=true\nclose=true\nplaceholder=Minutes, such as 45\n\n'
  awake && printf 'row=off\ntitle=Turn off\n\n'
  duration 1800 '30 minutes'; echo
  duration 3600 '1 hour'; echo
  duration 7200 '2 hours'; echo
  duration 14400 '4 hours'; echo
  duration 28800 '8 hours'; echo
  duration 0 'Until turned off'
}

# Runs `caffeinate` for that many seconds, or until it is stopped, in a watcher that ends the call when it ends by itself.
hold() {
  held=$1
  secs=$2
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

# Prints a value of the stdin of the call, which comes escaped on its input line.
given() {
  printf '%b\n' "$input" | sed -n "s/^$1=//p" | head -n 1
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
    start*)
      minutes=$(given minutes)
      [ -n "$minutes" ] || minutes=$(given search)
      case $minutes in
        '')
          printf 'call=%s\n---\ntitle=Keep the Mac awake\n\nfield=minutes\ntitle=Minutes\nplaceholder=45\n---\nend=%s\n---\n' "$call" "$call"
          ;;
        *[!0-9]* | 0*)
          printf 'call=%s\n---\ntoast=Caffeinate takes minutes as a number, such as 45.\n%s\n---\nend=%s\n---\n' "$call" "$(sheet)" "$call"
          ;;
        *)
          release
          hold "$call" $(( minutes * 60 ))
          printf '%s%s\n---\ncall=%s\n---\ntoast=%s\ndetail=%s\n---\n' "$ended" "$(sheet)" "$call" "$(toast "$secs")" "$(left)"
          ;;
      esac
      ;;
    open\ [0-9]*)
      release
      hold "$call" "${2%%.*}"
      printf '%s%s\n---\ncall=%s\n---\ntoast=%s\ndetail=%s\n---\n' "$ended" "$(sheet)" "$call" "$(toast "$secs")" "$(left)"
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
input=
while IFS= read -r line; do
  case $line in
    call=*) call=${line#call=}; input=; set -- ;;
    input=*) input=${line#input=} ;;
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
