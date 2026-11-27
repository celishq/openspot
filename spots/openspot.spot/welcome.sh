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

# Prints the heading of a page in a box that is as tall as its words, 24 points under the sheet's header: the title in
# large type, then the words under it.
heading() {
  printf '\nbox=head\nclass=gap-2 px-1.5 pt-3\n'
  printf '\ntext=title\nparent=head\nclass=font-heading\ntitle=%s\n' "$1"
}

lead() {
  printf '\ntext=detail\nparent=head\nclass=font-lead text-secondary\ntitle=%s\n' "$1"
}

# Prints a hand-drawn note of the heading, which welcome.swift draws in the accent colour, always at one height.
drawing() {
  printf '\nwelcome=note\nparent=head\nclass=h-10\ngrow=false\ndrawing=%s/%s\n' "$here" "$1"
}

# Prints one thing to try on the last page, which welcome.swift draws like a spot's card: its title, detail, icon and the
# hand-drawn number on its icon.
card() {
  printf '\nwelcome=%s\nparent=cards\nclass=h-16\ngrow=false\ntitle=%s\ndetail=%s\nicon=%s\nnote=%s/%s\n' "$1" "$2" "$3" "$4" "$here" "$5"
}

# Prints the box of the buttons, 24 points under what is above it.
buttons() {
  printf '\nbox=end\nclass=gap-part pt-6\n'
}

# Prints the first page: what a spot is, a handwritten "even this onboarding" in the accent colour, then Continue.
welcome() {
  printf 'frame=\nclass=gap-0\n'
  heading 'Everything is a disposable spot'
  drawing even-this-onboarding.svg
  lead 'Make a script or an app for anything. Keep it, throw it away, or share it in one click.'
  buttons
  printf '\nbutton=next\nparent=end\ntitle=Continue\nclass=bg-accent\nclose=false\n'
}

# Prints the key page: the chosen key, or the key that opens Openspot, then Use this key and Record another key. With an argument, the field records at once.
keys() {
  shown=$(chosen)
  printf 'frame=key\nclass=gap-0\n'
  heading 'Choose your key'
  lead 'It opens Openspot from any app.'
  printf '\nbox=body\nclass=pt-5\n'
  printf '\nfield=key\nparent=body\nclass=h-32\ntype=hotkey\n'
  openspot_kv value "${shown:-$now}"
  if [ -n "${1-}" ]; then printf 'recording=true\n'; else printf 'recording=false\n'; fi
  buttons
  printf '\nbutton=use\nparent=end\ntitle=Use this key\nclass=bg-accent\nclose=false\n'
  printf '\nbutton=record\nparent=end\ntitle=Record another key\nshortcut=backspace\nclose=false\n'
}

# Prints the last page: the two things to try, a spot of your own and a change by your agent, then Start using Openspot.
agent() {
  printf 'frame=agent\nclass=gap-0\n'
  heading 'Make it yours'
  lead 'Easily, with any of your favourite agents'
  drawing note-and-pls.svg
  printf '\nbox=cards\nclass=gap-part pt-1.5\n'
  card card-1 'Create your own spot' 'Open New spot and describe it.' plus note-1.svg
  card card-2 'Change it with your agent' 'Select it and press ⌘E.' pencil note-2.svg
  buttons
  printf '\nbutton=done\nparent=end\ntitle=Start using Openspot\nclass=bg-accent\nclose=false\n'
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
