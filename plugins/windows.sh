#!/bin/sh
# name=Windows
# symbol=macwindow
# subtitle=Give each command a key in Settings
# grid=false
# command=full:Full screen
# command=center:Centre
# command=left:Left side
# command=right:Right side
case "$1" in
  full) openspot window move "0 0 1/1 1" ;;
  center) openspot window move "7/40 7/40 13/20 13/20" ;;
  left) openspot window move "0 0 1/4 1" "0 0 1/3 1" "0 0 1/2 1" ;;
  right) openspot window move "3/4 0 1/4 1" "2/3 0 1/3 1" "1/2 0 1/2 1" ;;
  *) printf 'toast=Give each command a key in Settings\n' ;;
esac
