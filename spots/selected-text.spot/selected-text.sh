#!/bin/sh
# Puts the text selected in the app in front in the panel's field, where Tab offers it to each spot that takes text.
# It reads the selection when the panel opens, and adds nothing when no text is selected.
case "$1" in
  show)
    app=$(openspot front app | sed -n 's/^app=//p')
    [ -n "$app" ] || exit 0
    { openspot text selected "$app" && echo "title=Selected text"; } | openspot attachment add
    ;;
esac
