#!/bin/sh
# title=Settings
# icon=gearshape
# detail=Choose your key
# on=sheet.open
# uses=app,spots
# offers=card
# offers=search

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
  printf 'type=hotkey\nshortcut=%s\nshake=true\n' "${5:-Record}"
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

# Takes a row of spot $1: the spot gets a row on the first sheet, and the row shows on the page of that spot.
add() {
  case " $has " in *" $1 "*) ;; *) has="$has $1" ;; esac
  [ "$page" != "spot:$1" ] || out="$out$2$nl"
}

# Takes the block that ends: a spot gives its menu bar and float rows, a button its key row, and a field its row.
flush() {
  case $kind in
    spot)
      spot=$id name=$b_name icon=$b_icon
      names="$names$spot$nl$name$nl$icon$nl"
      [ "$b_menubar" != true ] || add "$spot" "${nl}row=menubar:$spot${nl}title=Show in the menu bar${nl}detail=$name${nl}parent=$name${nl}icon=$icon${nl}hides=clear${nl}value=$b_in"
      [ "$b_float" != true ] || add "$spot" "$(keyrow "float:$spot" Float "$name" "$icon" "$b_floatKey")"
      ;;
    button) add "$spot" "$(keyrow "key:$spot:$id" "$b_title" "$name" "${b_icon:-$icon}" "$b_key")" ;;
    field)
      named="$named$spot $id$nl"
      add "$spot" "$(settingrow "$spot" "$id" "$b_title" "${b_icon:-${icon:-gearshape}}" "$name")"
      ;;
  esac
  kind= id= b_name= b_icon= b_title= b_key= b_float= b_floatKey= b_menubar= b_in=
}

# Sets `name` and `icon` to those of spot $1, or to its ID and a gear when it left the folder.
named_spot() {
  name=$1 icon=gearshape
  while IFS= read -r known && IFS= read -r known_name && IFS= read -r known_icon; do
    [ "$known" = "$1" ] && { name=$known_name icon=$known_icon; return; }
  done <<EOF
$names
EOF
}

# Prints the sheet from the frames of the batch: the values, the state of the app, then the spots. The first sheet holds
# the keys of the app and a row for each spot with settings, and the page spot:<id> holds the settings of that spot.
sheet() {
  part=1 values= names= named= kind= careful= has= out= page=${OPENSPOT_PAGE-}
  while IFS= read -r line; do
    case $part:$line in
      *:---) flush; part=$((part + 1)) ;;
      *:) flush ;;
      1:field=*) value_key=${line#field=} ;;
      1:spot=*) value_spot=${line#spot=} ;;
      1:value=*) values="$values$value_spot$nl$value_key$nl${line#value=}$nl" ;;
      2:panelKey=*) panel=${line#*=} ;;
      2:fixKey=*) fix=${line#*=} ;;
      2:careful=*) careful=${line#*=} ;;
      2:login=*) login=${line#*=} ;;
      2:link=*) link=${line#*=} ;;
      3:spot=* | 3:button=* | 3:field=*) flush; kind=${line%%=*} id=${line#*=} ;;
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
  while IFS= read -r value_spot && IFS= read -r value_key && IFS= read -r value; do
    case $value_key in '' | *[[:space:]]* | icon) continue ;; esac
    case "$nl$named" in *"$nl$value_spot $value_key$nl"*) continue ;; esac
    named_spot "$value_spot"
    add "$value_spot" "$(settingrow "$value_spot" "$value_key" "$(titled "$value_key")" "$icon" "$name")"
  done <<EOF
$values
EOF
  if [ -n "$page" ]; then
    printf '%s' "$out"
    return
  fi
  printf '\nrow=panel_key\ntitle=Open Openspot\nicon=keyboard\nhides=clear\ntype=hotkey\nshortcut=%s\n' "$panel"
  printf '\nrow=fix_key\ntitle=Open a fix\nicon=wrench.and.screwdriver\nhides=clear\ntype=hotkey\nshortcut=%s\n' "$fix"
  printf '\nrow=careful_mode\ntitle=Careful mode\ndetail=Spots get only what their uses name\nicon=lock.shield\nvalue=%s\n' "$careful"
  [ -z "$login" ] || printf '\nrow=open_at_login\ntitle=Open at login\nicon=power\nvalue=%s\n' "$login"
  [ -z "$link" ] || printf '\nrow=command_link\ntitle=Use openspot in Terminal\ndetail=The command line tool\nicon=terminal\nvalue=%s\n' "$link"
  for spot in $has; do
    named_spot "$spot"
    printf '\nrow=spot:%s\ntitle=%s\nicon=%s\nopen=Open\nhides=clear\npage=true\n' "$spot" "$name" "$icon"
  done
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
      menubar:*)
        id=${2#menubar:}
        if in_menu_bar "$id"; then on=false; else on=true; fi
        exec openspot setting set --spot "$id" menubar "$on"
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
  panel_key) exec openspot setting set --spot openspot panel-key "$2" ;;
  fix_key) exec openspot setting set --spot openspot fix-key "$2" ;;
  clear)
    case "$2" in
      setting:*) setting "$2"; exec openspot setting set --spot "$spot" "$key" ;;
      key:*) command "$2"; exec openspot setting set --spot "$spot" "key.$key" ;;
      float:*) exec openspot setting set --spot "${2#float:}" float ;;
    esac
    ;;
  key:*) command "$1"; exec openspot setting set --spot "$spot" "key.$key" "$2" ;;
  float:*) exec openspot setting set --spot "${1#float:}" float "$2" ;;
  *)
    echo 'Settings cannot do that.' >&2
    exit 1
    ;;
esac
