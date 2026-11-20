#!/bin/sh
# Snooze closes the front Safari tab once the person picks a time on the snooze sheet, and due opens it again.
# The sheet starts with Snooze Current Tab, pinned, then lists each snoozed tab: Return opens it now, and Remove
# forgets it. Open All opens every one now. The rows also show in the main search. A timer keeps "<url> <title>".
. "$OPENSPOT_SH"

# Prints each timer as a line: id, time, url, title, split by tabs.
timers() {
  openspot timer list 2>/dev/null | openspot_rows text at title | while IFS="$(printf '\t')" read -r id at value; do
    printf '%s\t%s\t%s\t%s\n' "$id" "$at" "${value%% *}" "${value#* }"
  done
}

# The words of a time, such as Thu 8:00.
when() {
  seconds=$(date -j -u -f "%Y-%m-%dT%H:%M:%SZ" "$1" +%s 2>/dev/null) || { printf '%s' "$1"; return; }
  date -r "$seconds" "+%a %b %-d, %-H:%M"
}

# The icon of a page: its site's favicon, which Openspot fetches once, or Safari's for a page with no web address.
icon() {
  case "$1" in
    http://*|https://*) printf '%s/favicon.ico' "$(printf '%s' "$1" | sed -E 's#^(https?://[^/]+).*#\1#')" ;;
    *) printf safari ;;
  esac
}

# Snoozes the front Safari tab until the time the person picks, and closes it.
snooze_front() {
  url=$(osascript -e 'tell application "Safari" to get URL of current tab of front window' 2>/dev/null)
  [ -n "$url" ] || { echo "Safari shows no tab." >&2; exit 1; }
  title=$(osascript -e 'tell application "Safari" to get name of current tab of front window' 2>/dev/null)
  at=$(openspot spot ask openspot/snooze) || exit 0
  if [ "$at" != someday ]; then
    openspot timer add "$at" "$url $title" >/dev/null || exit 1
  fi
  osascript -e 'tell application "Safari" to close current tab of front window' >/dev/null
  openspot toast "Snoozed the tab."
}

case "$1" in
  show)
    printf 'button=remove\ntitle=Remove\nshortcut=cmd+backspace\n'
    openspot_item current "Snooze Current Tab" "Safari's front tab" moon.zzz
    printf 'pin=top\nhides=remove\nclose=false\n'
    timers | while IFS="$(printf '\t')" read -r id at url title; do
      openspot_item "$id" "${title:-$url}" "$(when "$at")" "$(icon "$url")"
    done
    ;;
  open)
    [ "$2" = current ] && { snooze_front; exit; }
    url=$(timers | awk -F '\t' -v id="$2" '$1 == id { print $3 }')
    [ -n "$url" ] || exit 0
    openspot timer remove "$2" >/dev/null && open "$url"
    ;;
  remove)
    [ -n "$2" ] && [ "$2" != current ] && openspot timer remove "$2" >/dev/null
    ;;
  wake)
    timers | while IFS="$(printf '\t')" read -r id at url title; do
      openspot timer remove "$id" >/dev/null && open "$url"
    done
    ;;
  snooze)
    snooze_front
    ;;
  due)
    open "$(value event.value | cut -d ' ' -f 1)"
    ;;
esac
