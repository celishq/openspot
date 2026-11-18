#!/bin/sh
# title=Welcome spot
# icon=hand.wave
# on=sheet.open
# uses=app
# offers=none
# starts=first-launch
# view=welcome.swift
# pages=key
# pages=agent
. "$OPENSPOT_SH"
keyfile="$OPENSPOT_DATA/welcome-key"
here=$(cd "${0%/*}" && pwd)

# Prints the key that the person recorded, or nothing.
chosen() {
  [ -f "$keyfile" ] && IFS= read -r line < "$keyfile" && printf '%s' "$line"
}

# Sets now to the key that opens Openspot, in the form of a key text such as option+space. A failing status ends the call.
current() {
  state=$(openspot app status) || exit 1
  now=ctrl+space
  while IFS= read -r line; do
    case $line in "panel-key="*) now=${line#*=}; break ;; esac
  done <<EOF2
$state
EOF2
}

# Prints a key text such as option+k as its marks, such as ⌥K.
label() {
  marks=''
  rest=$1
  while :; do
    case $rest in
      ctrl+*) marks="${marks}⌃" ;;
      option+*) marks="${marks}⌥" ;;
      shift+*) marks="${marks}⇧" ;;
      cmd+*) marks="${marks}⌘" ;;
      *) break ;;
    esac
    rest=${rest#*+}
  done
  case $rest in
    space) rest=Space ;; tab) rest=Tab ;; return) rest=⏎ ;; backspace) rest=⌫ ;; escape) rest=Esc ;;
    left) rest=← ;; right) rest=→ ;; up) rest=↑ ;; down) rest=↓ ;;
    *) rest=$(printf '%s' "$rest" | tr '[:lower:]' '[:upper:]') ;;
  esac
  printf '%s%s' "$marks" "$rest"
}

# Prints one thing to try on the last page, which welcome.swift draws like a spot's card: its title, detail, icon and the
# hand-drawn number on its icon.
card() {
  printf 'card.title=%s\ncard.detail=%s\ncard.icon=%s\ncard.note=%s\n' "$1" "$2" "$3" "$4"
}

# Prints the heading of a page, which welcome.swift draws: its words in large type, the words under them, then a hand-drawn
# note when it names one. It keeps the height of its grid lines.
heading() {
  printf '\nview=head\ngrow=false\ntitle=%s\ndetail=%s\n' "$1" "$2"
  [ -z "${3-}" ] || printf 'note=%s\n' "$3"
}

# Prints the first page: what a spot is, a handwritten "even this onboarding" in the accent colour, then Continue.
welcome() {
  printf 'grid=head head head head\ngrid=head head head head\ngrid=head head head head\ngrid=head head head head\n'
  printf 'grid=next next next next\n'
  heading 'Everything is a disposable spot' 'Make a script or an app for anything. Keep it, throw it away, or share it in one click.'
  printf 'icon=%s/even-this-onboarding.svg\n' "$here"
  printf '\nbutton=next\ntitle=Continue\nlook=strong\nshortcut=return\n'
}

# Prints the key page: the chosen key, or the key that opens Openspot, then Use this key and Record another key. With an argument, the field records at once.
keys() {
  shown=$(chosen)
  printf 'grid=head head head head\ngrid=head head head head\ngrid=key key key key\ngrid=key key key key\ngrid=key key key key\ngrid=use use use use\ngrid=record record record record\n'
  heading 'Choose your key' 'It opens Openspot from any app.'
  printf '\nfield=key\ntype=hotkey\n'
  openspot_kv value "${shown:-$now}"
  [ -z "${1-}" ] || printf 'recording=true\n'
  printf '\nbutton=use\ntitle=Use this key\nlook=strong\nshortcut=return\n'
  printf '\nbutton=record\ntitle=Record another key\nshortcut=escape\n'
}

# Prints the last page: the two things to try, a spot of your own and a change by your agent, then Start using Openspot.
agent() {
  printf 'grid=head head head head\ngrid=head head head head\ngrid=head head head head\ngrid=head head head head\n'
  printf 'grid=head head head head\ngrid=head head head head\ngrid=done done done done\n'
  heading 'Make it yours' 'Easily, with any of your favourite agents' "$here/note-and-pls.svg"
  card 'Create your own spot' 'Open New spot and describe it.' plus "$here/note-1.svg"
  card 'Change it with your agent' 'Select it and press ⌘E.' pencil "$here/note-2.svg"
  printf '\nbutton=done\ntitle=Start using Openspot\nlook=strong\nshortcut=return\n'
}

case "$1" in
  read)
    case "${OPENSPOT_PAGE-}" in
      key) current; keys ;;
      agent) agent ;;
      *) welcome ;;
    esac
    ;;
  next) printf 'push=key\npush.title=Choose your key\n' ;;
  key)
    printf '%s\n' "$2" > "$keyfile"
    current
    keys
    ;;
  record)
    current
    keys recording
    ;;
  use)
    key=$(chosen)
    if [ -n "$key" ]; then
      openspot setting set --spot openspot panel-key "$key" || exit 1
      rm -f "$keyfile"
    fi
    printf 'push=agent\npush.title=Make it yours\n'
    ;;
  done)
    current
    openspot spot pop openspot/welcome --all || exit 1
    printf 'pop=true\ntoast=Press `%s` to open Openspot\n' "$(label "$now")"
    ;;
  *)
    echo 'Welcome cannot do that.' >&2
    exit 1
    ;;
esac
