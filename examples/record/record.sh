#!/bin/sh
# title=Record
# icon=record.circle
# detail=Record the screen, again to stop
state=$(openspot screen record status | head -n 1)
if [ "$state" = "state=recording" ]; then
  files=$(openspot screen record stop) || exit 1
  file=$(printf '%s\n' "$files" | head -n 1)
  openspot clipboard copy "$file" && echo "toast=Copied the recording."
  exit 0
fi
inputs=$(openspot setting get --spot record/inputs inputs)
openspot screen record start $inputs || exit 1
state=$(openspot screen record status | head -n 1)
[ "$state" = "state=recording" ] && echo "toast=Recording the screen. Run Record again to stop it."
exit 0
