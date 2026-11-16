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

# Prints the page: the chosen key, or the key that opens Openspot, then Use this key and Record new combination.
page() {
  shown=$(chosen)
  printf 'grid=key key key key\ngrid=key key key key\ngrid=use use use use\ngrid=record record record record\n\n'
  printf 'field=key\ntype=hotkey\n'
  openspot_kv value "${shown:-$now}"
  printf '\nbutton=use\ntitle=Use this key\nlook=strong\nshortcut=return\n'
  printf '\nbutton=record\ntitle=Record new combination\nrecords=key\nshortcut=escape\n'
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
    if [ -n "$key" ]; then
      openspot setting set --spot openspot panel-key "$key" || exit 1
      rm -f "$keyfile"
    fi
    printf 'pop=true\n'
    ;;
  *)
    echo 'Welcome cannot do that.' >&2
    exit 1
    ;;
esac
