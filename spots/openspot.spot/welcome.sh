#!/bin/sh
# title=Welcome
# icon=hand.wave
# detail=Choose your key
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

# Prints the key that opens Openspot now, in the form of a key text such as option+space.
current() {
  state=$(openspot app status --frame) || exit 1
  while IFS= read -r line; do
    case $line in "panel-key="*) printf '%s' "${line#*=}"; return ;; esac
  done <<EOF2
$state
EOF2
  printf 'ctrl+space'
}

# Prints the label of the key text $1, such as ⌥Space for option+space.
label() {
  rest=${1:-ctrl+space}
  out=
  while :; do
    case $rest in
      *+*) word=${rest%%+*}; rest=${rest#*+} ;;
      *) word=$rest; rest=; last=1 ;;
    esac
    case $word in
      ctrl) out="${out}⌃" ;;
      option) out="${out}⌥" ;;
      shift) out="${out}⇧" ;;
      cmd) out="${out}⌘" ;;
      *)
        first=$(printf '%s' "$word" | cut -c1 | tr '[:lower:]' '[:upper:]')
        out="${out}${first}$(printf '%s' "$word" | cut -c2-)"
        ;;
    esac
    [ -z "${last-}" ] || break
  done
  printf '%s' "$out"
}

# Prints the head and the blocks of the page, with the head lines in $1 before its layout.
page() {
  printf '%s' "${1-}"
  printf 'title=Choose your key\ndetail=Press the keys that open Openspot\n'
  printf 'grid=key key key key\ngrid=key key key key\ngrid=use use use use\ngrid=keep keep again again\n\n'
  printf 'field=key\ntype=hotkey\n'
  openspot_kv value "$(chosen)"
  printf '\nbutton=use\ntitle=Use this key\nlook=strong\nshortcut=return\n'
  printf '\nbutton=keep\ntitle=Keep %s\nshortcut=escape\n' "$(label "$(current)")"
  printf '\nbutton=again\ntitle=Try again\nshortcut=backspace\n'
}

case "$1" in
  read) page ;;
  key)
    printf '%s\n' "$2" > "$keyfile"
    page
    ;;
  use)
    key=$(chosen)
    if [ -z "$key" ]; then
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
    page
    ;;
  *)
    echo 'Welcome cannot do that.' >&2
    exit 1
    ;;
esac
