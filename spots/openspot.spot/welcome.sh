#!/bin/sh
# title=Welcome
# icon=hand.wave
# detail=Openspot in three steps
# on=sheet.open
# uses=app
# offers=none
# edits=launch
# pages=key
# pages=agent
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

# Prints one line of a page: its id, its words and its icon.
line() {
  printf '\ntext=%s\nlook=tile\ntitle=%s\nicon=%s\n' "$1" "$2" "$3"
}

# Prints the first page: what Openspot is, then Continue.
welcome() {
  printf 'grid=opens opens opens opens\ngrid=spots spots spots spots\ngrid=agents agents agents agents\ngrid=next next next next\n'
  printf 'title=Welcome to Openspot\ndetail=The launcher that grows with you\n'
  line opens 'One key opens it from any app' keyboard
  line spots 'Each tool on it is a spot' square.grid.2x2
  line agents 'Your agent makes and changes spots' sparkles
  printf '\nbutton=next\ntitle=Continue\nlook=strong\nshortcut=return\n'
}

# Prints the key page: the chosen key, or the key that opens Openspot, then Use this key and Record new combination.
keys() {
  shown=$(chosen)
  printf 'grid=key key key key\ngrid=key key key key\ngrid=use use use use\ngrid=record record record record\n'
  printf 'title=Choose your key\ndetail=It opens Openspot from any app\n\n'
  printf 'field=key\ntype=hotkey\n'
  openspot_kv value "${shown:-$now}"
  printf '\nbutton=use\ntitle=Use this key\nlook=strong\nshortcut=return\n'
  printf '\nbutton=record\ntitle=Record new combination\nrecords=key\nshortcut=escape\n'
}

# Prints the last page: how an agent changes any spot, then Start using Openspot.
agent() {
  printf 'grid=file file file file\ngrid=new new new new\ngrid=edit edit edit edit\ngrid=copy copy copy copy\ngrid=done done done done\n'
  printf 'title=Make it yours\ndetail=Your agent writes and changes spots\n'
  line file 'Each spot is one small file' doc.text
  line new 'Ask your agent for a new one' sparkles
  line edit 'Select a spot and press ⌘E' pencil
  line copy '⌘⏎ copies the prompt for your agent' doc.on.clipboard
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
  use)
    key=$(chosen)
    if [ -n "$key" ]; then
      openspot setting set --spot openspot panel-key "$key" || exit 1
      rm -f "$keyfile"
    fi
    printf 'push=agent\npush.title=Make it yours\n'
    ;;
  done) printf 'pop=all\n' ;;
  *)
    echo 'Welcome cannot do that.' >&2
    exit 1
    ;;
esac
