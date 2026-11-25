#!/bin/sh
# Puts what you selected in the app in front in the panel's field, where Tab offers it to each spot that takes it: the
# files selected in Finder, or the text selected in any other app. It reads when the panel opens, and adds nothing when
# nothing is selected.
case "$1" in
  show)
    app=$(openspot front app | sed -n 's/^app=//p')
    [ -n "$app" ] || exit 0
    picked=$(openspot selection read "$app")
    [ -n "$picked" ] || exit 0
    case "$picked" in
      text=*) printf '%s\ntitle=Selected text\n' "$picked" ;;
      *) printf '%s\n' "$picked" ;;
    esac | openspot attachment add
    ;;
esac
