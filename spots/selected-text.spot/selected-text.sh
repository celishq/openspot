#!/bin/sh
# Puts the text selected in the app in front in the panel's field, where Tab offers it to each spot that takes text.
# It asks the app through Accessibility when the panel opens, and adds nothing when no text is selected.
case "$1" in
  show)
    app=$(lsappinfo info -only bundleid "$(lsappinfo front)" | sed -n 's/^.*bundleID="\([^"]*\)".*$/\1/p')
    text=$(osascript -e 'tell application "System Events" to set front_app to first application process whose frontmost is true' \
      -e 'tell application "System Events" to return value of attribute "AXSelectedText" of (value of attribute "AXFocusedUIElement" of front_app)' 2>/dev/null)
    [ -n "$(printf '%s' "$text" | tr -d '[:space:]')" ] || exit 0
    openspot attachment add text="$text" title="Selected text" ${app:+app="$app"}
    ;;
esac
exit 0
