#!/bin/sh
. "$OPENSPOT_SH"

# The settings of the app alone. Each spot keeps its own in its Settings sheet, which ⌘⏎ on its card opens.

# Prints the value of key $2 in the state of the app $1.
field() {
  while IFS= read -r line; do
    case $line in "$2="*) printf '%s' "${line#*=}"; return ;; esac
  done <<EOF
$1
EOF
}

# Prints the value of a key of the state of the app.
status() {
  state=$(openspot app status) || exit 1
  field "$state" "$1"
}

# Prints the sheet from the state of the app.
sheet() {
  login=$(field "$1" login)
  link=$(field "$1" link)
  slow=$(field "$1" slow)
  printf 'frame=\nrecents=false\n\nbutton=press\ntitle=Change\nclose=false\n'
  printf '\nfield=panel-key\ntype=hotkey\ntitle=Open Openspot\nicon=keyboard\nvalue=%s\n' "$(field "$1" panel-key)"
  printf '\nfield=fix-key\ntype=hotkey\ntitle=Open a fix\nicon=wrench.and.screwdriver\nvalue=%s\n' "$(field "$1" fix-key)"
  printf '\nitem=careful_mode\ntitle=Careful mode\ndetail=Spots get only what their uses name\nicon=lock.shield\nvalue=%s\n' "$(field "$1" careful)"
  [ -z "$slow" ] || printf '\nitem=slow_motion\ntitle=Slow motion\ndetail=Every motion ten times slower\nicon=tortoise\nvalue=%s\n' "$slow"
  [ -z "$login" ] || printf '\nitem=open_at_login\ntitle=Open at login\nicon=power\nvalue=%s\n' "$login"
  [ -z "$link" ] || printf '\nitem=command_link\ntitle=Use openspot in Terminal\ndetail=The command line tool\nicon=terminal\nvalue=%s\n' "$link"
}

case "$1" in
  show)
    state=$(openspot app status) || exit 1
    sheet "$state"
    ;;
  press)
    case "$(value item)" in
      open_at_login)
        if [ "$(status login)" = true ]; then on=false; else on=true; fi
        exec openspot setting set --spot openspot login "$on"
        ;;
      careful_mode)
        if [ "$(status careful)" = true ]; then on=false; else on=true; fi
        exec openspot setting set --spot openspot careful "$on"
        ;;
      slow_motion)
        if [ "$(status slow)" = true ]; then on=false; else on=true; fi
        exec openspot setting set --spot openspot slow "$on"
        ;;
      command_link)
        if [ "$(status link)" = true ]; then
          openspot setting set --spot openspot link false && openspot toast 'Removed openspot'
        else
          openspot setting set --spot openspot link true && openspot toast 'Installed openspot'
        fi
        ;;
      *)
        echo 'Settings cannot do that.' >&2
        exit 1
        ;;
    esac
    ;;
  panel-key) exec openspot setting set --spot openspot panel-key "$(value value)" ;;
  fix-key) exec openspot setting set --spot openspot fix-key "$(value value)" ;;
  *)
    echo 'Settings cannot do that.' >&2
    exit 1
    ;;
esac
