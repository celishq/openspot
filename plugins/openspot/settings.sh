#!/bin/sh
# title=Settings
# icon=gearshape
# detail=Choose your key
# size=small
# read=panel,sheet
# offers=search
# uses=app,settings

# The spot and the key of a setting row, from setting:<spot>:<key>.
setting() {
  rest=${1#setting:}
  spot=${rest%%:*}
  key=${rest#*:}
}

# The spot and the command of a key row, from key:<spot>:<command>.
command() {
  rest=${1#key:}
  spot=${rest%:*}
  key=${rest##*:}
}

nl='
'

# Prints a key with its first letter in capitals, as the title of a value that no header names.
titled() {
  lower=abcdefghijklmnopqrstuvwxyz
  upper=ABCDEFGHIJKLMNOPQRSTUVWXYZ
  rest=${1#?}
  first=${1%"$rest"}
  before=${lower%%"$first"*}
  if [ ${#before} -lt 26 ]; then
    i=0
    while [ "$i" -lt ${#before} ]; do upper=${upper#?}; i=$((i + 1)); done
    first=${upper%"${upper#?}"}
  fi
  printf '%s%s' "$first" "$rest"
}

# Sets `found` to the value that spot $1 keeps under key $2, and fails when it keeps none.
kept() {
  found=
  while IFS= read -r kept_spot && IFS= read -r kept_key && IFS= read -r kept_value; do
    [ "$kept_spot" = "$1" ] && [ "$kept_key" = "$2" ] && { found=$kept_value; return 0; }
  done <<EOF
$values
EOF
  return 1
}

# Prints the row of a key of a command or a float: its id, title, spot name, icon and key.
keyrow() {
  printf '\nrow=%s\ntitle=%s\ndetail=%s\nparent=%s\nicon=%s\n' "$1" "$2" "$3" "$3" "$4"
  [ -n "$5" ] || printf 'hides=clear\n'
  printf 'shortcut=%s\nshake=true\n' "${5:-Record}"
}

# Prints the row of a value of a spot: the spot, the key, the title, the icon and the name of the spot.
settingrow() {
  printf '\nrow=setting:%s:%s\ntitle=%s\n' "$1" "$2" "$3"
  if kept "$1" "$2"; then
    printf 'detail=%s · %s\nparent=%s\nicon=%s\n' "$5" "$found" "$5" "$4"
  else
    printf 'detail=%s · Not set\nparent=%s\nicon=%s\nhides=clear\n' "$5" "$5" "$4"
  fi
}

# Takes the block that ends: a spot gives its menu bar and float rows, a command its key row, and a setting its row.
flush() {
  case $kind in
    spot)
      spot=$id name=$b_name icon=$b_icon
      names="$names$spot$nl$name$nl$icon$nl"
      [ "$b_menubar" != true ] || menubars="$menubars${nl}row=menubar:$spot${nl}title=Show in the menu bar${nl}detail=$name${nl}parent=$name${nl}icon=$icon${nl}hides=clear${nl}value=$b_in$nl"
      [ "$b_float" != true ] || floats="$floats$(keyrow "float:$spot" Float "$name" "$icon" "$b_floatKey")$nl"
      ;;
    command) keys="$keys$(keyrow "key:$spot:$id" "$b_title" "$name" "${b_icon:-$icon}" "$b_key")$nl" ;;
    setting)
      named="$named$spot $id$nl"
      settings="$settings$(settingrow "$spot" "$id" "$b_title" "${b_icon:-${icon:-gearshape}}" "$name")$nl"
      ;;
  esac
  kind= id= b_name= b_icon= b_title= b_key= b_float= b_floatKey= b_menubar= b_in=
}

# Prints the sheet from the frames of the batch: the values, the state of the app, then the spots.
sheet() {
  part=1 values= names= named= menubars= floats= keys= settings= kind= careful=
  while IFS= read -r line; do
    case $part:$line in
      *:---) flush; part=$((part + 1)) ;;
      *:) flush ;;
      1:setting=*) value_key=${line#setting=} ;;
      1:spot=*) value_spot=${line#spot=} ;;
      1:value=*) values="$values$value_spot$nl$value_key$nl${line#value=}$nl" ;;
      2:panelKey=*) panel=${line#*=} ;;
      2:fixKey=*) fix=${line#*=} ;;
      2:careful=*) careful=${line#*=} ;;
      2:login=*) login=${line#*=} ;;
      2:link=*) link=${line#*=} ;;
      3:spot=* | 3:command=* | 3:setting=*) flush; kind=${line%%=*} id=${line#*=} ;;
      3:name=*) b_name=${line#*=} ;;
      3:icon=*) b_icon=${line#*=} ;;
      3:title=*) b_title=${line#*=} ;;
      3:key=*) b_key=${line#*=} ;;
      3:float=*) b_float=${line#*=} ;;
      3:floatKey=*) b_floatKey=${line#*=} ;;
      3:menubar=*) b_menubar=${line#*=} ;;
      3:inMenuBar=*) b_in=${line#*=} ;;
    esac
  done <<EOF
$1
EOF
  printf 'recents=false\n\nbutton=open\ntitle=Change\nclose=false\n\nbutton=clear\ntitle=Remove\nshortcut=cmd+backspace\n'
  printf '\nrow=panel_key\ntitle=Open Openspot\nicon=keyboard\nhides=clear\nshortcut=%s\n' "$panel"
  printf '\nrow=fix_key\ntitle=Open a fix\nicon=wrench.and.screwdriver\nhides=clear\nshortcut=%s\n' "$fix"
  printf '\nrow=careful_mode\ntitle=Careful mode\ndetail=Spots get only what their uses name\nicon=lock.shield\nvalue=%s\n' "$careful"
  [ -z "$login" ] || printf '\nrow=open_at_login\ntitle=Open at login\nicon=power\nvalue=%s\n' "$login"
  [ -z "$link" ] || printf '\nrow=command_link\ntitle=Use openspot in Terminal\ndetail=The command line tool\nicon=terminal\nvalue=%s\n' "$link"
  printf '%s%s%s%s' "$menubars" "$floats" "$keys" "$settings"
  while IFS= read -r value_spot && IFS= read -r value_key && IFS= read -r value; do
    case $value_key in '' | *[[:space:]]*) continue ;; esac
    case "$nl$named" in *"$nl$value_spot $value_key$nl"*) continue ;; esac
    name=$value_spot icon=gearshape
    while IFS= read -r known && IFS= read -r known_name && IFS= read -r known_icon; do
      [ "$known" = "$value_spot" ] && { name=$known_name icon=$known_icon; break; }
    done <<EOF
$names
EOF
    printf '%s\n' "$(settingrow "$value_spot" "$value_key" "$(titled "$value_key")" "$icon" "$name")"
  done <<EOF
$values
EOF
}

# Prints the value of a key of the state of the app.
status() {
  state=$(openspot app status --frame) || exit 1
  while IFS= read -r line; do
    case $line in "$1="*) printf '%s' "${line#*=}"; return ;; esac
  done <<EOF
$state
EOF
}

# Whether the spot with this ID shows in the menu bar.
in_menu_bar() {
  spots=$(openspot spot list --frame) || exit 1
  current=
  while IFS= read -r line; do
    case $line in
      spot=*) current=${line#spot=} ;;
      inMenuBar=true) [ "$current" = "$1" ] && return 0 ;;
    esac
  done <<EOF
$spots
EOF
  return 1
}

case "$1" in
  read)
    frames=$(openspot batch <<EOF
setting list --frame
app status --frame
spot list --frame
EOF
) || exit 1
    sheet "$frames"
    ;;
  open)
    case "$2" in
      open_at_login)
        if [ "$(status login)" = true ]; then exec openspot app login off; else exec openspot app login on; fi
        ;;
      careful_mode)
        if [ "$(status careful)" = true ]; then exec openspot app careful off; else exec openspot app careful on; fi
        ;;
      command_link)
        if [ "$(status link)" = true ]; then
          openspot app link off && echo 'toast=Removed openspot'
        else
          openspot app link on && echo 'toast=Installed openspot'
        fi
        ;;
      menubar:*)
        id=${2#menubar:}
        if in_menu_bar "$id"; then exec openspot menubar off "$id"; else exec openspot menubar on "$id"; fi
        ;;
      setting:*)
        setting "$2"
        exec openspot setting change --spot "$spot" "$key"
        ;;
      *)
        echo 'Settings cannot do that.' >&2
        exit 1
        ;;
    esac
    ;;
  panel_key) exec openspot key set --panel "$2" ;;
  fix_key) exec openspot key set --fix "$2" ;;
  clear)
    case "$2" in
      setting:*) setting "$2"; exec openspot setting set --spot "$spot" "$key" ;;
      key:*) command "$2"; exec openspot key set "$spot" "$key" ;;
      float:*) exec openspot key set "${2#float:}" --float ;;
    esac
    ;;
  key:*) command "$1"; exec openspot key set "$spot" "$key" "$2" ;;
  float:*) exec openspot key set "${1#float:}" --float "$2" ;;
  *)
    echo 'Settings cannot do that.' >&2
    exit 1
    ;;
esac
