#!/bin/sh
# title=Shelf
# icon=tray.full
# detail=Keeps files at hand
# drop=*
# on=sheet.open
list="$OPENSPOT_DATA/files"
. "$OPENSPOT_SH"

forget() {
  [ -f "$list" ] || return 0
  for path; do
    grep -vxF "$path" "$list" > "$list.new"
    mv "$list.new" "$list"
  done
}

case "$1" in
  read)
    printf 'recents=false\n\n'
    printf 'button=reveal\ntitle=Show in Finder\nshortcut=cmd+return\n\n'
    printf 'button=remove\ntitle=Remove from Shelf\nshortcut=cmd+backspace\n\n'
    printf 'button=clear\ntitle=Clear Shelf\nscope=spot\n\n'
    [ -f "$list" ] || exit 0
    while IFS= read -r path; do
      [ -e "$path" ] || continue
      folder=${path%/*}
      case "$folder" in "$HOME"*) folder="~${folder#"$HOME"}" ;; esac
      openspot_row "$path" "${path##*/}" "$folder" "$path"
      openspot_kv file "$path"
    done < "$list"
    ;;
  drop)
    shift
    touch "$list"
    for path; do
      grep -qxF "$path" "$list" || printf '%s\n' "$path" >> "$list"
    done
    openspot_kv select "$1"
    ;;
  drag | remove)
    shift
    forget "$@"
    ;;
  clear)
    rm -f "$list"
    ;;
  reveal)
    open -R "$2"
    ;;
  open)
    open "$2"
    ;;
esac
