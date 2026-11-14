#!/bin/sh
# title=Settings
# icon=gearshape
# detail=Choose your key
# on=panel.open
# on=sheet.open
# offers=search
# uses=app

# The settings of the app alone. Each spot keeps its own in its Settings sheet, which ⌘⏎ on its card opens.

# Prints the value of key $2 in the state of the app $1.
value() {
  while IFS= read -r line; do
    case $line in "$2="*) printf '%s' "${line#*=}"; return ;; esac
  done <<EOF
$1
EOF
}

# Prints the value of a key of the state of the app.
status() {
  state=$(openspot app status --frame) || exit 1
  value "$state" "$1"
}

# Prints the sheet from the state of the app.
sheet() {
  login=$(value "$1" login)
  link=$(value "$1" link)
  printf 'recents=false\n\nbutton=open\ntitle=Change\nclose=false\n'
  printf '\nrow=panel_key\ntitle=Open Openspot\nicon=keyboard\ntype=hotkey\nshortcut=%s\n' "$(value "$1" panelKey)"
  printf '\nrow=fix_key\ntitle=Open a fix\nicon=wrench.and.screwdriver\ntype=hotkey\nshortcut=%s\n' "$(value "$1" fixKey)"
  printf '\nrow=careful_mode\ntitle=Careful mode\ndetail=Spots get only what their uses name\nicon=lock.shield\nvalue=%s\n' "$(value "$1" careful)"
  [ -z "$login" ] || printf '\nrow=open_at_login\ntitle=Open at login\nicon=power\nvalue=%s\n' "$login"
  [ -z "$link" ] || printf '\nrow=command_link\ntitle=Use openspot in Terminal\ndetail=The command line tool\nicon=terminal\nvalue=%s\n' "$link"
}

case "$1" in
  read)
    state=$(openspot app status --frame) || exit 1
    sheet "$state"
    ;;
  open)
    case "$2" in
      open_at_login)
        if [ "$(status login)" = true ]; then on=false; else on=true; fi
        exec openspot setting set --spot openspot login "$on"
        ;;
      careful_mode)
        if [ "$(status careful)" = true ]; then on=false; else on=true; fi
        exec openspot setting set --spot openspot careful "$on"
        ;;
      command_link)
        if [ "$(status link)" = true ]; then
          openspot setting set --spot openspot link false && echo 'toast=Removed openspot'
        else
          openspot setting set --spot openspot link true && echo 'toast=Installed openspot'
        fi
        ;;
      *)
        echo 'Settings cannot do that.' >&2
        exit 1
        ;;
    esac
    ;;
  panel_key) exec openspot setting set --spot openspot panel-key "$2" ;;
  fix_key) exec openspot setting set --spot openspot fix-key "$2" ;;
  *)
    echo 'Settings cannot do that.' >&2
    exit 1
    ;;
esac
