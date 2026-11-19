#!/bin/sh
# Snooze closes the front Safari tab once the person picks a time on the snooze sheet, and due opens it again.
# The sheet lists each snoozed tab: Return opens it now, and Remove forgets it. A timer keeps "<url> <title>".
. "$OPENSPOT_SH"

# Prints each timer as a line: id, time, url, title, split by tabs.
timers() {
  openspot timer list 2>/dev/null | awk '
    /^text=/ { id = substr($0, 6) }
    /^title=/ { value = substr($0, 7) }
    /^at=/ { at = substr($0, 4) }
    /^$/ { if (id != "") print id "\t" at "\t" value; id = ""; value = ""; at = "" }
    END { if (id != "") print id "\t" at "\t" value }
  ' | while IFS="$(printf '\t')" read -r id at value; do
    printf '%s\t%s\t%s\t%s\n' "$id" "$at" "${value%% *}" "${value#* }"
  done
}

# The words of a time, such as Thu 8:00.
when() {
  seconds=$(date -j -u -f "%Y-%m-%dT%H:%M:%SZ" "$1" +%s 2>/dev/null) || { printf '%s' "$1"; return; }
  date -r "$seconds" "+%a %b %-d, %-H:%M"
}

case "$1" in
  show)
    printf 'button=remove\ntitle=Remove\nshortcut=cmd+backspace\n\n'
    listed=$(timers)
    if [ -z "$listed" ]; then
      openspot_item none "No snoozed tabs" "Press the Snooze Tab key on a Safari tab." moon.zzz
      exit 0
    fi
    printf '%s\n' "$listed" | while IFS="$(printf '\t')" read -r id at url title; do
      openspot_item "$id" "${title:-$url}" "$(when "$at")" safari
    done
    ;;
  open)
    [ "$2" = none ] && exit 0
    url=$(timers | awk -F '\t' -v id="$2" '$1 == id { print $3 }')
    [ -n "$url" ] || exit 0
    openspot timer remove "$2" >/dev/null && open "$url"
    ;;
  remove)
    [ -n "$2" ] && [ "$2" != none ] && openspot timer remove "$2" >/dev/null
    ;;
  snooze)
    url=$(osascript -e 'tell application "Safari" to get URL of current tab of front window' 2>/dev/null)
    [ -n "$url" ] || { echo "Safari shows no tab." >&2; exit 1; }
    title=$(osascript -e 'tell application "Safari" to get name of current tab of front window' 2>/dev/null)
    at=$(openspot timer pick) || exit 0
    if [ "$at" != someday ]; then
      openspot timer add "$at" "$url $title" >/dev/null || exit 1
    fi
    osascript -e 'tell application "Safari" to close current tab of front window' >/dev/null
    openspot toast "Snoozed the tab."
    ;;
  due)
    open "$(value event.value | cut -d ' ' -f 1)"
    ;;
esac
