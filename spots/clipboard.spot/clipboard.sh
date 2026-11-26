#!/bin/sh
# Puts what you copied in the last 2 minutes in the panel's field: files as files, a link as a link, a picture as an
# image file and anything else as text, where Tab offers it to each spot that takes it. Openspot counts the age of a copy
# from the first time it sees it, and reads a long text or a picture only when you hand it on.
# Each copy also goes into the timeline, in its kind, unless Keep history is off. A password goes nowhere. A copy of
# the same value moves its entry to the top, since its key is the value's hash.
case "$1" in
  show) openspot attachment add clipboard --within 2m ;;
  clipboard.change)
    [ "$(sed -n 's/^setting.history=//p')" = false ] && exit 0
    copy=$(openspot clipboard read --blocks) || exit 1
    [ -n "$copy" ] || exit 0
    printf '%s\nkey=%s\n' "$copy" "$(printf '%s' "$copy" | /usr/bin/shasum | cut -c 1-16)" | openspot timeline add >/dev/null
    ;;
esac
