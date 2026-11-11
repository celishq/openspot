#!/bin/sh
# title=Shelf
# icon=tray.full
# detail=Keeps files at hand
# drop=*
# read=sheet
# offers=float
list="$OPENSPOT_DATA/files"

esc() {
  printf '%s' "$1" | sed 's/\\/\\\\/g'
}

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
    printf 'button=clear\ntitle=Clear Shelf\nscope=command\n\n'
    [ -f "$list" ] || exit 0
    while IFS= read -r path; do
      [ -e "$path" ] || continue
      folder=${path%/*}
      case "$folder" in "$HOME"*) folder="~${folder#"$HOME"}" ;; esac
      value=$(esc "$path")
      printf 'row=%s\ntitle=%s\ndetail=%s\nicon=%s\nfile=%s\n\n' "$value" "$(esc "${path##*/}")" "$(esc "$folder")" "$value" "$value"
    done < "$list"
    ;;
  drop)
    shift
    touch "$list"
    for path; do
      grep -qxF "$path" "$list" || printf '%s\n' "$path" >> "$list"
    done
    printf 'select=%s\n' "$(esc "$1")"
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
