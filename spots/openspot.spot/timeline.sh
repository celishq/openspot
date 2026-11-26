#!/bin/sh
. "$OPENSPOT_SH"

# The timeline of every spot, newest first, under a heading for each day: the newest 500 entries, or the 500 newest
# that hold each word typed in the sheet. Return pastes a text, a picture or a file into the front app and opens a link,
# ⌘C copies, ⌘⌫ forgets the entry, with a toast that puts it back, and Tab hands it to a spot that takes it.

# Prints the newest entry for the card when the panel opens.
card() {
  openspot timeline list --all --limit 1 | awk -v today="$(date +%F)" -v yesterday="$(date -v-1d +%F)" -v card=1 -f "${0%/*}/timeline.awk"
}

# Prints the frame of the entries that hold the words of $1.
list() {
  days=$(value setting.keep | tr -dc 0-9)
  openspot timeline keep "${days:-30}" || exit 1
  if [ -n "$1" ]; then
    entries=$(openspot timeline list --all --limit 500 --text "$1") || exit 1
  else
    entries=$(openspot timeline list --all --limit 500) || exit 1
  fi
  printf 'frame=\nrecents=false\n'
  printf '%s\n' "$entries" | awk -v today="$(date +%F)" -v yesterday="$(date -v-1d +%F)" -f "${0%/*}/timeline.awk"
}

# Copies the entry of the pressed row, or of the inputs of `use` when $1 is empty.
copy() {
  case $(value "${1}kind") in
    text)
      whole=$(value "${1}whole")
      if [ -n "$whole" ]; then openspot clipboard copy < "$whole"; else printf '%s' "$(value "${1}text")" | openspot clipboard copy; fi
      ;;
    url) printf '%s' "$(value "${1}url")" | openspot clipboard copy ;;
    *) openspot clipboard copy "$(value "${1}file")" ;;
  esac
}

# Pastes the entry into the front app, or opens a link.
use() {
  if [ "$(value "${1}kind")" = url ]; then
    open "$(value "${1}url")"
    exit 0
  fi
  copy "$1" || exit 1
  exec openspot clipboard paste
}

forgotten="$OPENSPOT_DATA/forgotten"
case "$1" in
  show)
    if [ "$(value event)" = panel.open ]; then card; else list ""; fi
    ;;
  sheet.text) list "$(value value)" ;;
  command) exec openspot spot open openspot/timeline ;;
  press)
    [ "$(value item)" = empty ] && exit 0
    use item.
    ;;
  use) use "" ;;
  copy) copy item. && openspot toast "Copied." ;;
  forget)
    id=$(value item)
    openspot timeline forget "$id" || exit 1
    printf '%s' "$id" > "$forgotten"
    openspot toast --id forgot --action restore "Forgot it. Click to put it back."
    list ""
    ;;
  restore)
    id=$(cat "$forgotten" 2>/dev/null)
    rm -f "$forgotten"
    openspot toast --remove forgot
    [ -n "$id" ] && openspot timeline restore "$id"
    ;;
  pause) openspot timeline pause 1h && openspot toast "Timeline keeps nothing for an hour." ;;
  resume) openspot timeline resume && openspot toast "Timeline keeps what you copy again." ;;
  *)
    echo 'Timeline cannot do that.' >&2
    exit 1
    ;;
esac
