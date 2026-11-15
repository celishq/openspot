#!/bin/sh
# title=Record
# icon=record.circle
# detail=Record the screen, again to stop
# uses=screen,clipboard
# offers=card
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
inputs=$(openspot setting get --spot record/inputs inputs)
openspot screen record start $inputs || exit 1
state=$(openspot screen record status | head -n 1)
[ "$state" = "state=recording" ] && echo "toast=Recording the screen. Run Record again to stop it."
exit 0
