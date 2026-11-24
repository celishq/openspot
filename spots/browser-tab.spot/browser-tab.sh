#!/bin/sh
# Puts the front tab of the browser in front in the panel's field, with its title, where Tab offers it to each spot that
# takes a link. It reads the tab only when Tab picks its chip over a browser.
case "$1" in
  attachment.pick) tab=$(openspot browser tab) && printf '%s\n' "$tab" | openspot attachment add ;;
esac
