#!/bin/sh
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
# note when it names one. It is as tall as the class $1 says.
heading() {
  printf '\nwelcome=head\nclass=%s\ngrow=false\ntitle=%s\ndetail=%s\n' "$1" "$2" "$3"
  [ -z "${4-}" ] || printf 'note=%s\n' "$4"
}

# Prints the first page: what a spot is, a handwritten "even this onboarding" in the accent colour, then Continue.
welcome() {
  printf 'frame=\nclass=gap-part\n'
  heading h-44 'Everything is a disposable spot' 'Make a script or an app for anything. Keep it, throw it away, or share it in one click.'
  printf 'icon=%s/even-this-onboarding.svg\n' "$here"
  printf '\nbutton=next\ntitle=Continue\nclass=bg-accent\nshortcut=return\nclose=false\n'
}

# Prints the key page: the chosen key, or the key that opens Openspot, then Use this key and Record another key. With an argument, the field records at once.
keys() {
  shown=$(chosen)
  printf 'frame=key\nclass=gap-part\n'
  heading h-24 'Choose your key' 'It opens Openspot from any app.'
  printf '\nfield=key\nclass=h-32\ntype=hotkey\n'
  openspot_kv value "${shown:-$now}"
  [ -z "${1-}" ] || printf 'recording=true\n'
  printf '\nbutton=use\ntitle=Use this key\nclass=bg-accent\nshortcut=return\nclose=false\n'
  printf '\nbutton=record\ntitle=Record another key\nshortcut=escape\nclose=false\n'
}

# Prints the last page: the two things to try, a spot of your own and a change by your agent, then Start using Openspot.
agent() {
  printf 'frame=agent\nclass=gap-part\n'
  heading h-72 'Make it yours' 'Easily, with any of your favourite agents' "$here/note-and-pls.svg"
  card 'Create your own spot' 'Open New spot and describe it.' plus "$here/note-1.svg"
  card 'Change it with your agent' 'Select it and press ⌘E.' pencil "$here/note-2.svg"
  printf '\nbutton=done\ntitle=Start using Openspot\nclass=bg-accent\nshortcut=return\nclose=false\n'
}

case "$1" in
  show)
    case "$(value route)" in
      key) current; keys ;;
      agent) agent ;;
      *) welcome ;;
    esac
    ;;
  next) openspot route push key --title 'Choose your key' ;;
  key)
    printf '%s\n' "$(value value)" > "$keyfile"
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
    openspot route push agent --title 'Make it yours'
    ;;
  done)
    current
    openspot route close || exit 1
    openspot toast "Press \`$(label "$now")\` to open Openspot"
    ;;
  *)
    echo 'Welcome cannot do that.' >&2
    exit 1
    ;;
esac
