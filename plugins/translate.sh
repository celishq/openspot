#!/bin/sh
# symbol=translate
# subtitle=Into your languages
# key=t
# size=small
# read=click
# search=live
# recents=false
export LC_ALL=en_US.UTF-8
case "$1" in
  ""|search)
    printf 'action=open\ntitle=Copy\n\n'
    [ -n "$2" ] && "$OPENSPOT_APP" --translate "$2"
    exit 0
    ;;
  open)
    case "$2" in
      :settings:*)
        open "x-apple.systempreferences:com.apple.Localization-Settings.extension"
        ;;
      *)
        printf '%s' "$2" | pbcopy
        echo "toast=Copied"
        ;;
    esac
    ;;
esac
