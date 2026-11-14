#!/bin/sh
# title=Confetti
# icon=party.popper
# detail=Celebrate on each screen
# on=panel.open
#
# field=look
# title=Look
#
# field=key
# type=hotkey
# title=Shortcut
dir=$(cd "$(dirname "$0")" && pwd)/confetti
. "$dir/shared.sh"

case "$1" in
  read)
    [ -z "${OPENSPOT_REASON-}" ] || (listen > /dev/null 2>&1 &)
    title=$(look_title "$(default_look)")
    [ -n "$(openspot setting get look 2>/dev/null)" ] || openspot setting set look "$title" > /dev/null 2>&1
    printf 'detail=%s\n' "$(esc "$title")"
    ;;
  open | play)
    play "$(default_look)"
    ;;
  look)
    picked=${2:-$(value look)}
    if [ -n "$picked" ]; then
      set_default "$picked"
      openspot setting set look "$(look_title "$(default_look)")" > /dev/null 2>&1
      play "$(default_look)" quiet
    fi
    printf 'title=Look\n\nchoice=look\ntitle=Look\nvalue=%s\n\n' "$(default_look)"
    for id in $(look_ids); do printf 'option=%s\ntitle=%s\n\n' "$id" "$(esc "$(look_title "$id")")"; done
    ;;
  key)
    old=$(play_key)
    if [ -z "$2" ]; then
      save_key ""
      listening && kill "$pid"
      rm -f "$data/listen.pid"
      printf 'toast=%s\n' "$(esc "Confetti has no shortcut now. Record one in its Settings.")"
      exit 0
    fi
    if app_key "$2"; then
      fail "$(key_name "$2") belongs to the apps on your Mac, such as Copy or Paste. Hold ⌃ or ⌥ with a letter. $(key_name "$old") still plays it."
    fi
    save_key "$2"
    if ! listen; then
      reason=$(tail -n 1 "$data/listen.log" 2>/dev/null)
      save_key "$old"
      listen > /dev/null 2>&1
      fail "${reason:-Openspot cannot use that key.} $(key_name "$old") still plays it."
    fi
    printf 'toast=%s\n' "$(esc "$(key_name "$2") now plays confetti anywhere.")"
    ;;
esac
