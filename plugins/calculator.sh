#!/bin/sh
# title=Calculator
# icon=equal.square
# detail=Sums, units, currencies and dates
# answers=^\s*([-+(.$€£¥₴₿₹₩₺₪π0-9]|(?i:the|today|tomorrow|yesterday|now|time|next|last|in|days|weeks|months|years|hours|minutes|sqrt|sin|cos|tan|ln|log|abs|round|pi|noon|midnight)\b)
case "$1" in
  read)
    [ -n "$2" ] || exit 0
    answer=$(openspot calc solve "$2")
    case "$answer" in
      status=offline)
        printf 'row=offline\ntitle=No exchange rates\ndetail=Openspot cannot get exchange rates. Connect to the internet, then type again.\nicon=wifi.slash\n'
        ;;
      status=unavailable)
        printf 'row=offline\ntitle=No exchange rates\ndetail=The source of the rates does not answer. Sums, units and dates still work. Try again later.\nicon=exclamationmark.triangle\n'
        ;;
      *) printf '%s\n' "$answer" ;;
    esac
    ;;
  open)
    [ "$2" = offline ] && exit 0
    printf %s "$2" | pbcopy && printf 'toast=Copied %s\n' "$2"
    ;;
esac
