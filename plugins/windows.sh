#!/bin/sh
# name=Windows
# symbol=macwindow
# subtitle=Give each command a key in Settings
# grid=false
# command=full:Full screen
# command=center:Centre
# command=left:Left side
# command=right:Right side
margin=20

# Succeeds when two numbers are no more than the margin apart.
near() {
  [ $(($1 - $2)) -le "$margin" ] && [ $(($2 - $1)) -le "$margin" ]
}

# Prints the frame of a slot as x y width height, from the area and the window, each as x y width height.
# A side that the window already fills takes the next of 1/4, 1/3 and 1/2 of the area, then 1/4 again.
frame() {
  slot=$1 ax=$2 ay=$3 aw=$4 ah=$5 x=$6 y=$7 w=$8 h=$9
  case $slot in
    full)
      echo "$ax $ay $aw $ah"
      return
      ;;
    center)
      cw=$(((aw * 13 + 10) / 20))
      ch=$(((ah * 13 + 10) / 20))
      echo "$((ax + (aw - cw + 1) / 2)) $((ay + (ah - ch + 1) / 2)) $cw $ch"
      return
      ;;
  esac
  if [ "$slot" = left ]; then
    edge=$x side=$ax
  else
    edge=$((x + w)) side=$((ax + aw))
  fi
  next=$(((aw + 2) / 4))
  if near "$edge" "$side" && near "$y" "$ay" && near "$h" "$ah"; then
    for part in $(((aw + 2) / 4)) $(((2 * aw + 3) / 6)) $(((aw + 1) / 2)); do
      if [ "$part" -gt $((w + margin)) ]; then
        next=$part
        break
      fi
    done
  fi
  if [ "$slot" = left ]; then
    echo "$ax $ay $next $ah"
  else
    echo "$((ax + aw - next)) $ay $next $ah"
  fi
}

case "$1" in
  frame)
    frame "$2" "$3" "$4" "$5" "$6" "$7" "$8" "$9" "${10}"
    ;;
  full|center|left|right)
    current=$(openspot window frame) || exit 1
    set -- "$1" $current
    openspot window move $(frame "$1" "$6" "$7" "$8" "$9" "$2" "$3" "$4" "$5")
    ;;
  *)
    printf 'toast=Give each command a key in Settings\n'
    ;;
esac
