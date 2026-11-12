#!/bin/sh
# title=Windows
# icon=macwindow
# detail=Give each command a key
# uses=screen
#
# button=full
# title=Full screen
# icon=rectangle.inset.filled
#
# button=center
# title=Centre
# icon=rectangle.center.inset.filled
#
# button=left
# title=Left side
# icon=rectangle.lefthalf.inset.filled
#
# button=right
# title=Right side
# icon=rectangle.righthalf.inset.filled
case "$1" in
  full) openspot window move "0 0 1 1" ;;
  center) openspot window move "0.175 0.175 0.65 0.65" ;;
  left) openspot window move "0 0 1/4 1" "0 0 1/3 1" "0 0 1/2 1" ;;
  right) openspot window move "3/4 0 1/4 1" "2/3 0 1/3 1" "1/2 0 1/2 1" ;;
esac
