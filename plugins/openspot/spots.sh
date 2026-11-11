#!/bin/sh
# title=Spots
# icon=puzzlepiece.extension
# detail=Turn on
# size=small
# read=sheet
# uses=app,spots
nl='
'

# Prints the value of a key of the state of the app.
status() {
  state=$(openspot app status --frame) || exit 1
  while IFS= read -r line; do
    case $line in "$1="*) printf '%s' "${line#*=}"; return ;; esac
  done <<EOF
$state
EOF
}

# Prints a row for each core spot from its block, and the row of the login on a first launch from the state of the app.
sheet() {
  part=1 id= first= login=
  while IFS= read -r line; do
    case $part:$line in
      *:---) part=$((part + 1)) ;;
      1:spot=*) id=${line#spot=}; printf '\nrow=%s\n' "$id"; own= detail= ;;
      1:name=*) printf 'title=%s\n' "${line#*=}" ;;
      1:icon=*) printf 'icon=%s\n' "${line#*=}" ;;
      1:detail=*) detail=${line#*=} ;;
      1:own=*) own=${line#*=} ;;
      1:on=*) printf 'value=%s\n' "${line#*=}" ;;
      1:)
        if [ "$own" = true ]; then
          printf 'detail=In your plugins folder\n'
        elif [ -n "$detail" ]; then
          printf 'detail=%s\n' "$detail"
        fi
        own= detail=
        ;;
      2:firstLaunch=*) first=${line#*=} ;;
      2:login=*) login=${line#*=} ;;
    esac
  done <<EOF
$1
EOF
  [ "$first" != true ] || [ -z "$login" ] || printf '\nrow=open_at_login\ntitle=Open at login\nicon=power\nvalue=%s\nhides=review\n' "$login"
}

# Sets `on` and `own` from the block of one core spot, and fails when there is none.
choice() {
  spots=$(openspot spot list --core --frame) || exit 1
  current= on= own=
  while IFS= read -r line; do
    case $line in
      spot=*) [ "$current" != "$1" ] || return 0; current=${line#spot=} on= own= ;;
      on=*) on=${line#on=} ;;
      own=*) own=${line#own=} ;;
    esac
  done <<EOF
$spots
EOF
  [ "$current" = "$1" ]
}

case "$1" in
  read)
    frames=$(openspot batch <<EOF
spot list --core --frame
app status --frame
EOF
) || exit 1
    printf 'recents=false\n'
    printf '\nbutton=open\ntitle=Select\nclose=false\n'
    printf '\nbutton=select-all\ntitle=Select all\nshortcut=cmd+shift+a\nscope=command\n'
    printf '\nbutton=review\ntitle=Review code\n'
    printf '\nbutton=add\ntitle=Add a spot\nform=true\nscope=command\n'
    printf '\nrow=new\ntitle=New spot\ndetail=Make your own with AI or a starter\nicon=plus\nhides=review\n'
    sheet "$frames"
    ;;
  open)
    case "$2" in
      new)
        exec openspot spot open openspot/new
        ;;
      open_at_login)
        if [ "$(status login)" = true ]; then exec openspot app login off; else exec openspot app login on; fi
        ;;
    esac
    if ! choice "$2"; then
      echo 'Spots has no such spot.' >&2
      exit 1
    elif [ "$own" = true ]; then
      echo 'toast=This spot is a file in your plugins folder.'
    elif [ "$on" = true ]; then
      exec openspot spot off "$2"
    else
      exec openspot spot on "$2"
    fi
    ;;
  select-all)
    spots=$(openspot spot list --core --frame) || exit 1
    ids= current=
    while IFS= read -r line; do
      case $line in
        spot=*) current=${line#spot=} ;;
        own=false) ids="$ids $current" ;;
      esac
    done <<EOF
$spots
EOF
    [ -z "$ids" ] || exec openspot spot on $ids
    ;;
  review)
    [ -z "$2" ] || exec openspot spot review "$2"
    ;;
  add)
    source=$(sed -n 's/^source=//p' | head -1 | sed 's/\\\\/\\/g')
    if [ -z "$source" ]; then
      printf 'title=Add a spot\n\nfield=source\ntitle=Source\nplaceholder=Git URL, folder or .spot file\nrequired=true\n'
      exit 0
    fi
    added=$(openspot spot add "$source") || exit 1
    printf 'toast=%s\n' "$added"
    ;;
  *)
    echo 'Spots cannot do that.' >&2
    exit 1
    ;;
esac
