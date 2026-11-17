#!/bin/sh
# icon=cup.and.saucer.fill
# detail=Keep the Mac awake
# on=panel.open
# mode=stay
# offers=card
# uses=power

# One process answers every call. The call that turns Caffeinate on stays open while `caffeinate` runs, so Openspot
# keeps this process until it ends, and a quit of Openspot ends `caffeinate` too. With the lid on, a hold also runs
# `openspot power lid-closed`, which keeps the Mac awake with the lid closed for as long as it runs, and every end of
# the hold ends it.
held=
watcher=
until=0
picked=
lid=
holder=
fault=

awake() {
  [ -n "$watcher" ] && kill -0 "$watcher" 2>/dev/null
}

# Tells whether a hold keeps the Mac working with the lid closed. The setting is read from Openspot once, at its first use,
# which each call makes before it prints the sheet in a subshell, where a read would be lost.
lid_on() {
  [ -n "$lid" ] || lid=$(openspot setting get lid-closed </dev/null 2>/dev/null)
  [ "$lid" = true ] || lid=false
  [ "$lid" = true ]
}

# Keeps the lid-closed setting.
lid_keep() {
  lid=$1
  openspot setting set lid-closed "$1" </dev/null >/dev/null 2>&1
}

# Starts `openspot power lid-closed` and waits for its first line. Sets `holder` to its process while it holds, or
# `fault` to the line that says why it cannot.
lid_hold() {
  mkdir -p "$OPENSPOT_DATA"
  pipe=$OPENSPOT_DATA/lid.$$
  rm -f "$pipe"
  mkfifo "$pipe" || { fault="Openspot cannot start the lid-closed hold."; return 1; }
  openspot power lid-closed </dev/null >"$pipe" 2>"$OPENSPOT_DATA/lid.fault" &
  holder=$!
  said=
  read -r said <"$pipe"
  rm -f "$pipe"
  [ "$said" = on ] && return 0
  wait "$holder" 2>/dev/null
  holder=
  fault=$(head -n 1 "$OPENSPOT_DATA/lid.fault")
  return 1
}

# Prints the seconds that a hold has left, or 0 when it runs until it is stopped.
remaining() {
  if [ "$until" = 0 ]; then
    echo 0
    return
  fi
  seconds=$(( until - $(date +%s) ))
  [ "$seconds" -gt 0 ] || seconds=1
  echo "$seconds"
}

# Prints how long the Mac stays awake, which the card shows while the call that turned it on runs.
left() {
  seconds=$(remaining)
  if [ "$seconds" = 0 ]; then
    echo "Until off"
    return
  fi
  minutes=$(( (seconds + 59) / 60 ))
  if [ "$minutes" -ge 60 ]; then
    echo "$(( minutes / 60 ))h $(( minutes % 60 ))m left"
  else
    echo "${minutes}m left"
  fi
}

# Prints the row of one duration. The row of the duration that runs carries the id of its call, so that a pick of it
# is a new call that starts it again, and not a second press that would stop it.
duration() {
  if awake && [ "$1" = "$picked" ]; then
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
  duration 0 'Until turned off'; echo
  printf 'row=lid\ntitle=Work with the lid closed\ndetail=The screen can still lock\ntype=toggle\nvalue=%s\nclose=false\n' "${lid:-false}"
}

# Runs `caffeinate` for the duration picked, or for the seconds given after it, or until it is stopped, in a watcher
# that ends the call when it ends by itself. With the lid on, the display may sleep and the screen lock. Fails when the
# lid is on but the Mac refuses to hold it, which turns the lid off.
hold() {
  held=$1
  picked=$2
  seconds=${3:-$2}
  if [ "$seconds" = 0 ]; then until=0; else until=$(( $(date +%s) + seconds )); fi
  flags=-di
  closed=true
  holder=
  if lid_on; then
    if lid_hold; then
      flags=-i
    else
      closed=
      lid_keep false
    fi
  fi
  (
    trap 'kill $(jobs -p) $holder 2>/dev/null; exit 0' TERM
    if [ "$seconds" = 0 ]; then caffeinate $flags & else caffeinate $flags -t "$seconds" & fi
    wait $!
    [ -z "$holder" ] || kill "$holder" 2>/dev/null
    watcher=
    printf 'end=%s\n---\n%s\n---\n' "$1" "$(sheet)"
  ) &
  watcher=$!
  [ -n "$closed" ]
}

# Starts a hold on a call, as `hold` takes it, and prints the head that keeps the call running. A new pick, with no
# seconds given, gets a toast, and so does a hold that lost the lid.
begin() {
  said=
  hold "$@" || said="toast=$(toast "$2" lost)
"
  [ $# -ge 3 ] || [ -n "$said" ] || said="toast=$(toast "$2")
"
  printf '%s%s\n---\ncall=%s\n---\n%sdetail=%s\n---\n' "$ended" "$(sheet)" "$1" "$said" "$(left)"
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

# Prints the toast of a hold of that many seconds, which says, after `lost`, that it could not work with the lid closed,
# and why.
toast() {
  minutes=$(( $1 / 60 ))
  if [ "$1" = 0 ]; then on="Caffeinate is on until you turn it off"
  elif [ "$minutes" -ge 120 ]; then on="Caffeinate is on for $(( minutes / 60 )) hours"
  elif [ "$minutes" -eq 60 ]; then on="Caffeinate is on for 1 hour"
  elif [ "$minutes" -eq 1 ]; then on="Caffeinate is on for 1 minute"
  else on="Caffeinate is on for $minutes minutes"
  fi
  if [ "$2" = lost ]; then
    echo "$on, but not with the lid closed. $fault"
  else
    echo "$on"
  fi
}

# Answers one call. Each answer is one write, so that it never mixes with the frame of a watcher that ends. The call
# that turns Caffeinate on prints the rows before it starts, and then only a head with the time left, which the card
# shows while that call runs: a call that prints rows is not shown as running.
serve() {
  lid_on
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
          begin "$call" $(( minutes * 60 ))
          ;;
      esac
      ;;
    'open lid')
      if lid_on; then next=false; else next=true; fi
      if awake; then
        seconds=$(remaining)
        release
        lid_keep "$next"
        begin "$call" "$picked" "$seconds"
      else
        lid_keep "$next"
        printf 'call=%s\n---\n%s\n---\nend=%s\n---\n' "$call" "$(sheet)" "$call"
      fi
      ;;
    open\ [0-9]*)
      release
      begin "$call" "${2%%.*}"
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
