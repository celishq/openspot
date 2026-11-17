#!/bin/sh
# icon=cup.and.saucer.fill
# detail=Keep the Mac awake
# on=panel.open
# mode=stay
# offers=card

# One process answers every call. The call that turns Caffeinate on stays open while `caffeinate` runs, so Openspot
# keeps this process until it ends, and a quit of Openspot ends `caffeinate` too. With the lid on, a hold also turns
# sleep off through `pmset`, which a sudoers rule lets this user run without a password, and every end of the hold turns
# it on again. A mark in the data folder lives while sleep is off, so that the next start turns it on after a crash.
rule=/etc/sudoers.d/openspot-caffeinate
mark=$OPENSPOT_DATA/sleep-off
held=
watcher=
until=0
secs=
lid=

awake() {
  [ -n "$watcher" ] && kill -0 "$watcher" 2>/dev/null
}

# Tells whether a hold keeps the Mac working with the lid closed. The setting is read from Openspot once, at its first use.
lidded() {
  [ -n "$lid" ] || lid=$(openspot setting get lid </dev/null 2>/dev/null)
  [ "$lid" = true ] || lid=false
  [ "$lid" = true ]
}

# Sets `pmset disablesleep`, through the sudoers rule, and fails when the rule does not let it.
sleepless() {
  sudo -n /usr/bin/pmset disablesleep "$1" </dev/null >/dev/null 2>&1
}

# Turns sleep off while the lid is closed, after the mark that tells a later start to turn it on again.
stay() {
  : > "$mark"
  sleepless 1 || rm -f "$mark"
}

# Turns sleep on again, when a hold turned it off.
rest() {
  [ -f "$mark" ] || return 0
  sleepless 0 && rm -f "$mark"
}

# Installs the sudoers rule, which asks for the password of an administrator once.
allow() {
  entry="#$(id -u) ALL=(root) NOPASSWD: /usr/bin/pmset disablesleep 1, /usr/bin/pmset disablesleep 0"
  script="mkdir -p /etc/sudoers.d && echo '$entry' > $rule && chmod 0440 $rule && /usr/sbin/visudo -c -f $rule || { rm -f $rule; exit 1; }"
  osascript -e "do shell script \"$script\" with administrator privileges with prompt \"Caffeinate needs your password once to keep the Mac working with the lid closed.\"" </dev/null >/dev/null 2>&1
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
  duration 0 'Until turned off'; echo
  printf 'row=lid\ntitle=Work with the lid closed\ndetail=Lets the screen lock while the Mac keeps working\nclose=false\n'
  lidded && printf 'value=true\n'
}

# Runs `caffeinate` for the duration picked, or for the seconds given after it, or until it is stopped, in a watcher
# that ends the call when it ends by itself. With the lid on, the display may sleep and the screen lock.
hold() {
  held=$1
  secs=$2
  seconds=${3:-$2}
  if [ "$seconds" = 0 ]; then until=0; else until=$(( $(date +%s) + seconds )); fi
  flags=-di
  lidded && flags=-i
  (
    awake=
    trap '[ -z "$awake" ] || kill "$awake" 2>/dev/null; rest; exit 0' TERM
    [ "$flags" = -di ] || stay
    if [ "$seconds" = 0 ]; then caffeinate $flags & else caffeinate $flags -t "$seconds" & fi
    awake=$!
    wait "$awake"
    rest
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
    'open lid')
      if lidded; then
        lid=false
      elif sleepless 0 || { allow && sleepless 0; }; then
        lid=true
      else
        printf 'call=%s\n---\ntoast=Caffeinate works with the lid closed only with your password. Pick the row again to enter it.\n%s\n---\nend=%s\n---\n' "$call" "$(sheet)" "$call"
        return
      fi
      openspot setting set lid "$lid" </dev/null >/dev/null 2>&1
      if awake; then
        picked=$secs
        seconds=0
        [ "$until" = 0 ] || seconds=$(( until - $(date +%s) ))
        [ "$until" = 0 ] || [ "$seconds" -gt 0 ] || seconds=1
        release
        hold "$call" "$picked" "$seconds"
        printf '%s%s\n---\ncall=%s\n---\ndetail=%s\n---\n' "$ended" "$(sheet)" "$call" "$(left)"
      else
        printf 'call=%s\n---\n%s\n---\nend=%s\n---\n' "$call" "$(sheet)" "$call"
      fi
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

rest

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
