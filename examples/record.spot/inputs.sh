#!/bin/sh
# title=Record inputs
# icon=mic
# detail=The sound and the camera of Record
# on=sheet.open
# uses=screen
# offers=card
kept=$(openspot setting get inputs)

case "$1" in
  read)
    printf 'button=open\ntitle=Turn on or off\nclose=false\n\n'
    openspot screen sources | awk -v kept=" $kept " '
      BEGIN { RS = ""; FS = "\n" }
      $1 ~ /^row=(system|mic:.+|camera:.+)$/ {
        print
        if (index(kept, " " substr($1, 5) " ")) print "value=true"
        print ""
      }'
    ;;
  open)
    word=$2
    on=1
    next=""
    for each in $kept; do
      if [ "$each" = "$word" ]; then
        on=""
      elif [ "${each%%:*}" != "${word%%:*}" ]; then
        next="$next $each"
      fi
    done
    [ -z "$on" ] || next="$next $word"
    next=${next# }
    if [ -n "$next" ]; then
      openspot setting set inputs "$next"
    else
      openspot setting set inputs
    fi
    ;;
esac
