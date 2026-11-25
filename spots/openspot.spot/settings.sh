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

# Prints the row of the record read so far, except the theme, which Themes shows.
row() {
  [ -n "$key" ] && [ "$section" != look ] || return 0
  case $kind in
    key) printf '\nfield=%s\ntype=hotkey\ntitle=%s\nicon=%s\nvalue=%s\n' "$key" "$title" "$icon" "$value" ;;
    *)
      printf '\nitem=%s\ntitle=%s\n' "$key" "$title"
      [ -z "$detail" ] || printf 'detail=%s\n' "$detail"
      printf 'icon=%s\nvalue=%s\n' "$icon" "$value"
      ;;
  esac
}

# Prints the sheet from the rows of the app, which `openspot setting list` prints, and the state of the app.
sheet() {
  printf 'frame=\nrecents=false\n\nbutton=press\ntitle=Change\nclose=false\n'
  printf '%s\n\n' "$1" | while IFS= read -r line; do
    case $line in
      key=*) key=${line#*=} ;;
      title=*) title=${line#*=} ;;
      value=*) value=${line#*=} ;;
      kind=*) kind=${line#*=} ;;
      section=*) section=${line#*=} ;;
      icon=*) icon=${line#*=} ;;
      detail=*) detail=${line#*=} ;;
      '') row; key= title= value= kind= section= icon= detail= ;;
    esac
  done
  printf '\nitem=careful_mode\ntitle=Careful mode\ndetail=Spots get only what their uses name\nicon=lock.shield\nvalue=%s\n' "$(field "$2" careful)"
}

case "$1" in
  show)
    rows=$(openspot setting list --spot openspot) || exit 1
    state=$(openspot app status) || exit 1
    sheet "$rows" "$state"
    ;;
  press)
    case "$(value item)" in
      login)
        if [ "$(status login)" = true ]; then on=false; else on=true; fi
        exec openspot setting set --spot openspot login "$on"
        ;;
      careful_mode)
        if [ "$(status careful)" = true ]; then on=false; else on=true; fi
        exec openspot setting set --spot openspot careful "$on"
        ;;
      slow)
        if [ "$(status slow)" = true ]; then on=false; else on=true; fi
        exec openspot setting set --spot openspot slow "$on"
        ;;
      link)
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
