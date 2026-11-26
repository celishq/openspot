#!/bin/sh
. "$OPENSPOT_SH"

# The timeline of every spot, newest first, under a heading for each day: the newest 500 entries, or the 500 newest
# that hold each word typed in the sheet. Return copies an entry, ⌘Return pastes it into the front app, ⌘⌫ forgets
# it, with a toast that puts it back, and Tab hands it to a spot that takes it.


# Prints the frame of the newest entries that hold the words of $1: $2 of them, or 500.
list() {
  if [ -n "$1" ]; then
    entries=$(openspot timeline list --all --limit "${2:-500}" --text "$1") || exit 1
  else
    entries=$(openspot timeline list --all --limit "${2:-500}") || exit 1
  fi
  printf 'frame=\nrecents=false\n'
  printf '%s\n' "$entries" | awk -v today="$(date +%F)" -v yesterday="$(date -v-1d +%F)" -f "${0%/*}/timeline.awk"
}

# Copies the entry of the pressed row, or of the inputs of `use` when $1 is empty.
copy() {
  case $(value "${1}kind") in
    text)
      file=$(value "${1}file")
      if [ -n "$file" ]; then openspot clipboard copy < "$file"; else printf '%s' "$(value "${1}text")" | openspot clipboard copy; fi
      ;;
    url) printf '%s' "$(value "${1}url")" | openspot clipboard copy ;;
    *) openspot clipboard copy "$(value "${1}file")" ;;
  esac
}


forgotten="$OPENSPOT_DATA/forgotten"
case "$1" in
  show)
    days=$(value setting.keep | tr -dc 0-9)
    openspot timeline keep "$days" || exit 1
    list ""
    ;;
  sheet.text) list "$(value value)" "$(value limit)" ;;
  command) exec openspot spot open openspot/timeline ;;
  press)
    [ "$(value item)" = empty ] && exit 0
    copy item. && openspot toast "Copied."
    ;;
  paste)
    [ "$(value item)" = empty ] && exit 0
    copy item. || exit 1
    exec openspot clipboard paste
    ;;
  copy) copy "" && openspot toast "Copied." ;;
  forget)
    id=$(value item)
    openspot timeline forget "$id" || exit 1
    printf '%s' "$id" > "$forgotten"
    openspot toast --id forgot --action restore "Forgot it. Click to put it back."
    ;;
  restore)
    id=$(cat "$forgotten" 2>/dev/null)
    rm -f "$forgotten"
    openspot toast --remove forgot
    [ -n "$id" ] || exit 0
    openspot timeline restore "$id"
    ;;
  pause) openspot timeline pause 1h && openspot toast "Timeline keeps nothing for an hour." ;;
  resume) openspot timeline resume && openspot toast "Timeline keeps what you copy again." ;;
  *)
    echo 'Timeline cannot do that.' >&2
    exit 1
    ;;
esac
