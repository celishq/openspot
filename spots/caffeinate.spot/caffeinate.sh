#!/bin/sh

# One process answers every call. The call that turns Caffeinate on stays open while `caffeinate` runs, so Openspot
# keeps this process until it ends, and a quit of Openspot ends `caffeinate` too. With the lid on, a hold also runs
# `openspot power lid-closed`, which keeps the Mac awake with the lid closed for as long as it runs, and every end of
# the hold ends it.
held=
watcher=
until=0
picked=
lid=
display=
lidded=
holder=
fault=

awake() {
  [ -n "$watcher" ] && kill -0 "$watcher" 2>/dev/null
}

# Tells whether this Mac has a lid, as macOS reports a clamshell state only for one that has. Read once, at the start.
has_lid() {
  [ -n "$lidded" ] || if ioreg -r -k AppleClamshellState -d 1 2>/dev/null | grep -q AppleClamshellState; then lidded=true; else lidded=false; fi
  [ "$lidded" = true ]
}

# Tells whether a hold keeps the Mac working with the lid closed, which only a Mac with a lid can. The setting is read
# from Openspot once, at its first use, which each call makes before it prints the sheet in a subshell, where a read
# would be lost.
lid_on() {
  has_lid || { lid=false; return 1; }
  [ -n "$lid" ] || lid=$(openspot setting get lid-closed </dev/null 2>/dev/null)
  [ "$lid" = true ] || lid=false
  [ "$lid" = true ]
}

# Keeps the lid-closed setting.
lid_keep() {
  lid=$1
  openspot setting set lid-closed "$1" </dev/null >/dev/null 2>&1
}

# Tells whether a hold keeps the display on, which it does unless the setting says false. Read once, as `lid_on` is.
display_on() {
  [ -n "$display" ] || display=$(openspot setting get display-on </dev/null 2>/dev/null)
  [ "$display" = false ] || display=true
  [ "$display" = true ]
}

# Keeps the display-on setting.
display_keep() {
  display=$1
  openspot setting set display-on "$1" </dev/null >/dev/null 2>&1
}

# Starts `openspot power lid-closed` and reads its first line, `on` or the line that says why it cannot hold. Sets
# `holder` to its process while it holds, or `fault` to that line.
lid_hold() {
  mkdir -p "$OPENSPOT_DATA"
  pipe=$OPENSPOT_DATA/lid.$$
  rm -f "$pipe"
  mkfifo "$pipe" || { fault="Openspot cannot start the lid-closed hold."; return 1; }
  openspot power lid-closed </dev/null >"$pipe" 2>&1 &
  holder=$!
  first=
  read -r first <"$pipe"
  rm -f "$pipe"
  [ "$first" = on ] && return 0
  holder=
  fault=$first
  return 1
}

# Ends what a hold runs: `caffeinate`, and the lid hold when there is one.
let_go() {
  kill $(jobs -p) $holder 2>/dev/null
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

# Prints what the card shows while a hold runs: the time left, and that the lid can close when it holds the lid.
card() {
  if [ -n "$holder" ]; then echo "$(left) · lid closed"; else left; fi
}

# Prints the item of one duration. The item of the duration that runs carries the id of its call, so that a pick of it
# is a new call that starts it again, and not a second press that would stop it, and shows the time it has left.
duration() {
  if awake && [ "$1" = "$picked" ]; then
    printf 'text=%s.%s\ntitle=%s\ndetail=%s\n' "$1" "$held" "$2" "$(left)"
  else
    printf 'text=%s\ntitle=%s\n' "$1" "$2"
  fi
}

# Prints the items of the sheet, with Turn off first while the Mac is kept awake.
sheet() {
  printf 'frame=\nrecents=false\n\n'
  printf 'button=open\ntitle=Select\n\n'
  printf 'button=start\ntitle=Keep awake for…\nscope=spot\nform=true\nplaceholder=Minutes, such as 45\n\n'
  awake && printf 'text=off\ntitle=Turn off\n\n'
  duration 1800 '30 minutes'; echo
  duration 7200 '2 hours'; echo
  printf 'text=custom\ntitle=Custom…\n\n'
  duration 0 'Until turned off'; echo
  printf 'switch=display\ntitle=Keep the display on\ndetail=Off lets the screen lock\nicon=display\npin=bottom\nvalue=%s\nclose=false\n' "${display:-true}"
  [ "$lidded" = true ] || return 0
  printf '\nswitch=lid\ntitle=Work with the lid closed\ndetail=Can grow hot in a bag\nicon=laptopcomputer\npin=bottom\nvalue=%s\nclose=false\n' "${lid:-false}"
}

# Runs `caffeinate` for the duration picked, or for the seconds given after it, or until it is stopped, in a watcher
# that ends the call when it ends by itself. With the display off, the display may sleep and the screen lock. Fails when
# the lid is on but the Mac refuses to hold it, which turns the lid off.
hold() {
  held=$1
  picked=$2
  seconds=${3:-$2}
  if [ "$seconds" = 0 ]; then until=0; else until=$(( $(date +%s) + seconds )); fi
  if display_on; then flags=-di; else flags=-i; fi
  closed=true
  holder=
  if lid_on && ! lid_hold; then
    closed=
    lid_keep false
  fi
  (
    trap 'let_go; exit 0' TERM
    if [ "$seconds" = 0 ]; then caffeinate $flags & else caffeinate $flags -t "$seconds" & fi
    wait $!
    let_go
    watcher=
    printf 'end=%s\n---\n%s\n---\n' "$1" "$(sheet)"
  ) &
  watcher=$!
  [ -n "$closed" ]
}

# Starts a hold on a call, as `hold` takes it, and prints the head that keeps the call running. A new pick, with no
# seconds given, gets a toast, and so does a hold that lost the lid.
begin() {
  if ! hold "$@"; then
    openspot toast "$(toast "$2" lost)"
  elif [ $# -lt 3 ]; then
    openspot toast "$(toast "$2")"
  fi
  printf '%s%s\n---\ncall=%s\n---\nframe=\ndetail=%s\n---\n' "$ended" "$(sheet)" "$1" "$(card)"
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

# Prints a value of the stdin of the call, whose lines follow its arguments in the block of the call.
given() {
  printf '%s' "$input" | sed -n "s/^$1=//p" | head -n 1
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
# that turns Caffeinate on prints the items before it starts, and then only a head with the time left, which the card
# shows while that call runs: a call that prints items is not shown as running.
serve() {
  lid_on
  display_on
  case "$1 $2" in
    'open off')
      release
      openspot toast 'Caffeinate is off'
      printf '%scall=%s\n---\n%s\n---\nend=%s\n---\n' "$ended" "$call" "$(sheet)" "$call"
      ;;
    start* | 'open custom')
      minutes=$(given input.minutes)
      [ -n "$minutes" ] || minutes=$(given search)
      case $minutes in
        '')
          printf 'call=%s\n---\nframe=\ntitle=Keep the Mac awake\n\nfield=minutes\ntitle=Minutes\nplaceholder=45\n---\nend=%s\n---\n' "$call" "$call"
          ;;
        *[!0-9]* | 0*)
          openspot toast 'Caffeinate takes minutes as a number, such as 45.'
          printf 'call=%s\n---\n%s\n---\nend=%s\n---\n' "$call" "$(sheet)" "$call"
          ;;
        *)
          release
          begin "$call" $(( minutes * 60 ))
          ;;
      esac
      ;;
    'lid '* | 'display '*)
      if awake; then
        seconds=$(remaining)
        release
        "$1"_keep "$2"
        begin "$call" "$picked" "$seconds"
      else
        "$1"_keep "$2"
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
frame=
detail=$(card)
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
    *) [ -z "$call" ] || input="$input$line
" ;;
  esac
done
release
