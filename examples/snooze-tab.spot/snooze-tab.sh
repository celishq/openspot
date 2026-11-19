#!/bin/sh
# Snooze closes the front Safari tab once the person picks a time on the snooze sheet, and due opens it again.
case "$1" in
  snooze)
    url=$(osascript -e 'tell application "Safari" to get URL of current tab of front window' 2>/dev/null)
    [ -n "$url" ] || { echo "Safari shows no tab." >&2; exit 1; }
    at=$(openspot timer pick) || exit 0
    if [ "$at" != someday ]; then
      openspot timer add "$at" "$url" >/dev/null || exit 1
    fi
    osascript -e 'tell application "Safari" to close current tab of front window' >/dev/null
    openspot toast "Snoozed the tab."
    ;;
  due)
    open "$(sed -n 's/^event.value=//p')"
    ;;
esac
