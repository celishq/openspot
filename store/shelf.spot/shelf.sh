#!/bin/sh
list="$OPENSPOT_DATA/files"
. "$OPENSPOT_SH"

# Prints each value of an input, such as each file of a drop, on a line of its own.
each() {
  value "$1"
  printf '\n'
}

# Forgets each path on stdin.
forget() {
  [ -f "$list" ] || return 0
  while IFS= read -r path; do
    [ -n "$path" ] || continue
    grep -vxF "$path" "$list" > "$list.new"
    mv "$list.new" "$list"
  done
}

case "$1" in
  show)
    printf 'frame=\nrecents=false\n\n'
    printf 'button=reveal\ntitle=Show in Finder\nshortcut=cmd+return\n\n'
    printf 'button=remove\ntitle=Remove from Shelf\nshortcut=cmd+backspace\nclose=false\n\n'
    printf 'button=clear\ntitle=Clear Shelf\nscope=spot\nclose=false\n\n'
    [ -f "$list" ] || exit 0
    while IFS= read -r path; do
      [ -e "$path" ] || continue
      folder=${path%/*}
      case "$folder" in "$HOME"*) folder="~${folder#"$HOME"}" ;; esac
      openspot_item "$path" "${path##*/}" "$folder" "$path"
      openspot_kv file "$path"
    done < "$list"
    ;;
  drop)
    touch "$list"
    each file | while IFS= read -r path; do
      [ -n "$path" ] || continue
      grep -qxF "$path" "$list" || printf '%s\n' "$path" >> "$list"
    done
    openspot select "$(each file | head -n 1)"
    ;;
  drag | remove)
    each item | forget
    ;;
  clear)
    rm -f "$list"
    ;;
  reveal)
    open -R "$(value item)"
    ;;
  press)
    open "$(value item)"
    ;;
esac
