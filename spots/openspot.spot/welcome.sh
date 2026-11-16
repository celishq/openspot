#!/bin/sh
# title=Choose your key
# icon=keyboard
# detail=It opens Openspot from any app
# on=sheet.open
# uses=app
# offers=none
# edits=launch
. "$OPENSPOT_SH"
keyfile="$OPENSPOT_DATA/welcome-key"

# Prints the key that the person recorded, or nothing.
chosen() {
  [ -f "$keyfile" ] && IFS= read -r line < "$keyfile" && printf '%s' "$line"
}

# Sets now to the key that opens Openspot, in the form of a key text such as option+space. A failing status ends the call.
current() {
  state=$(openspot app status --frame) || exit 1
  now=ctrl+space
  while IFS= read -r line; do
    case $line in "panel-key="*) now=${line#*=}; break ;; esac
  done <<EOF2
$state
EOF2
}

# Prints the label of the key text $1 as the app draws it, such as ⌥Space for option+space: marks in the order ⌃⌥⇧⌘.
label() {
  rest=${1:-ctrl+space}
  marks=
  key=
  last=
  while [ -z "$last" ]; do
    case $rest in
      *+*) word=${rest%%+*}; rest=${rest#*+} ;;
      *) word=$rest; last=1 ;;
    esac
    case $word in
      ctrl|option|shift|cmd) marks="$marks $word" ;;
      return) key=⏎ ;;
      *) key="$(printf '%s' "$word" | cut -c1 | tr '[:lower:]' '[:upper:]')$(printf '%s' "$word" | cut -c2-)" ;;
    esac
  done
  out=
  for mark in ctrl:⌃ option:⌥ shift:⇧ cmd:⌘; do
    case " $marks " in *" ${mark%%:*} "*) out="$out${mark#*:}" ;; esac
  done
  printf '%s%s' "$out" "$key"
}

# Prints the head and the blocks of the page, with the head lines in $1 before its layout. Esc keeps the current key
# while the page listens, and tries again once a key shows.
page() {
  shown=$(chosen)
  printf '%s' "${1-}"
  printf 'grid=key key key key\ngrid=key key key key\ngrid=use use use use\ngrid=keep keep again again\n\n'
  printf 'field=key\ntype=hotkey\n'
  openspot_kv value "$shown"
  printf '\nbutton=use\ntitle=Use this key\nlook=strong\n'
  printf '\nbutton=keep\ntitle=Keep %s\n' "$(label "$now")"
  [ -n "$shown" ] || printf 'shortcut=escape\n'
  printf '\nbutton=again\ntitle=Try again\n'
  if [ -n "$shown" ]; then printf 'shortcut=escape\n'; else printf 'shortcut=backspace\n'; fi
}

case "$1" in
  read) current; page ;;
  key)
    printf '%s\n' "$2" > "$keyfile"
    current
    page
    ;;
  use)
    key=$(chosen)
    if [ -z "$key" ]; then
      current
      page 'toast=Press the keys you want first.
'
    else
      openspot setting set --spot openspot panel-key "$key" || exit 1
      rm -f "$keyfile"
      printf 'pop=true\n'
    fi
    ;;
  keep)
    rm -f "$keyfile"
    printf 'pop=true\n'
    ;;
  again)
    rm -f "$keyfile"
    current
    page
    ;;
  *)
    echo 'Welcome cannot do that.' >&2
    exit 1
    ;;
esac
