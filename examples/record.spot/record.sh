#!/bin/sh
# title=Record
# icon=record.circle
# detail=Record the screen, again to stop
# uses=screen,clipboard
# offers=card
#
# field=inputs
# title=Sound and camera
# icon=mic
. "$OPENSPOT_SH"
kept=${OPENSPOT_SETTING_INPUTS-}

# Turns an input on or off, and keeps one mic and one camera at most.
toggle() {
  on=1
  next=""
  for each in $kept; do
    if [ "$each" = "$1" ]; then
      on=""
    elif [ "${each%%:*}" != "${1%%:*}" ]; then
      next="$next $each"
    fi
  done
  [ -z "$on" ] || next="$next $1"
  kept=${next# }
}

case "$1" in
  inputs)
    picked=$(value inputs)
    if [ -n "$picked" ]; then
      for word in $picked; do toggle "$word"; done
      if [ -n "$kept" ]; then openspot setting set inputs "$kept"; else openspot setting set inputs; fi
    fi
    printf 'title=Sound and camera\n\nchoice=inputs\ntitle=Sound and camera\ntype=multiple\n'
    for word in $kept; do printf 'value=%s\n' "$word"; done
    openspot screen sources | awk 'BEGIN { RS = ""; FS = "\n" }
      $1 ~ /^row=(system|mic:.+|camera:.+)$/ {
        title = ""
        for (i = 2; i <= NF; i++) if ($i ~ /^title=/) title = substr($i, 7)
        printf "\noption=%s\ntitle=%s\n", substr($1, 5), title
      }'
    exit 0
    ;;
esac

state=$(openspot screen record status | head -n 1)
# A recording that macOS ended still waits for its stop, which names its files and says why it ended.
case "$state" in
  state=recording | state=ended)
    files=$(openspot screen record stop)
    code=$?
    file=$(printf '%s\n' "$files" | head -n 1)
    [ -n "$file" ] || exit 1
    openspot clipboard copy "$file" && echo "toast=Copied the recording."
    exit "$code"
    ;;
esac
openspot screen record start $kept || exit 1
state=$(openspot screen record status | head -n 1)
[ "$state" = "state=recording" ] && echo "toast=Recording the screen. Run Record again to stop it."
exit 0
