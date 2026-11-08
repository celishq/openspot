#!/bin/sh
# name=Windows
# symbol=macwindow
# subtitle=Give each command a key
# grid=false
# command=full:Full screen:rectangle.inset.filled
# command=center:Centre:rectangle.center.inset.filled
# command=left:Left side:rectangle.lefthalf.inset.filled
# command=right:Right side:rectangle.righthalf.inset.filled
case "$1" in
  full) openspot window move "0 0 1 1" ;;
  center) openspot window move "0.175 0.175 0.65 0.65" ;;
  left) openspot window move "0 0 1/4 1" "0 0 1/3 1" "0 0 1/2 1" ;;
  right) openspot window move "3/4 0 1/4 1" "2/3 0 1/3 1" "1/2 0 1/2 1" ;;
esac
