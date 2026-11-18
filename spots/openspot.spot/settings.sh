#!/bin/sh
# title=Settings
# icon=gearshape
# detail=Choose your key
# on=sheet.open
# uses=app
# offers=card
# offers=search

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
  state=$(openspot app status) || exit 1
  value "$state" "$1"
}

# Prints the sheet from the state of the app.
sheet() {
  login=$(value "$1" login)
  link=$(value "$1" link)
  slow=$(value "$1" slow)
  printf 'recents=false\n\nbutton=open\ntitle=Change\nclose=false\n'
  printf '\nrow=panel-key\ntitle=Open Openspot\nicon=keyboard\ntype=hotkey\nshortcut=%s\n' "$(value "$1" panel-key)"
  printf '\nrow=fix-key\ntitle=Open a fix\nicon=wrench.and.screwdriver\ntype=hotkey\nshortcut=%s\n' "$(value "$1" fix-key)"
  printf '\nrow=careful_mode\ntitle=Careful mode\ndetail=Spots get only what their uses name\nicon=lock.shield\nvalue=%s\n' "$(value "$1" careful)"
  [ -z "$slow" ] || printf '\nrow=slow_motion\ntitle=Slow motion\ndetail=Every motion ten times slower\nicon=tortoise\nvalue=%s\n' "$slow"
  [ -z "$login" ] || printf '\nrow=open_at_login\ntitle=Open at login\nicon=power\nvalue=%s\n' "$login"
  [ -z "$link" ] || printf '\nrow=command_link\ntitle=Use openspot in Terminal\ndetail=The command line tool\nicon=terminal\nvalue=%s\n' "$link"
  printf '\nrow=import_raycast\ntitle=Import from Raycast\ndetail=Bring your script commands\nicon=square.and.arrow.down\npush.spot=openspot/import\n'
}

case "$1" in
  read)
    state=$(openspot app status) || exit 1
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
      slow_motion)
        if [ "$(status slow)" = true ]; then on=false; else on=true; fi
        exec openspot setting set --spot openspot slow "$on"
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
  panel-key) exec openspot setting set --spot openspot panel-key "$2" ;;
  fix-key) exec openspot setting set --spot openspot fix-key "$2" ;;
  *)
    echo 'Settings cannot do that.' >&2
    exit 1
    ;;
esac
