#!/bin/sh
# title=Calculator
# icon=equal.square
# detail=Sums, units, currencies and dates
# answers=^\s*([-+(.$€£¥₴₿₹₩₺₪π0-9]|(?i:the|today|tomorrow|yesterday|now|time|next|last|in|days|weeks|months|years|hours|minutes|sqrt|sin|cos|tan|ln|log|abs|round|pi|noon|midnight)\b)
case "$1" in
  read)
    [ -n "$2" ] || exit 0
    answer=$(openspot calc solve "$2")
    if [ "$answer" = "status=offline" ]; then
      printf 'row=offline\ntitle=No exchange rates\ndetail=Openspot cannot get exchange rates. Connect to the internet, then type again.\nicon=wifi.slash\n'
    else
      printf '%s\n' "$answer"
    fi
    ;;
  open)
    [ "$2" = offline ] && exit 0
    printf %s "$2" | pbcopy && printf 'toast=Copied %s\n' "$2"
    ;;
esac
