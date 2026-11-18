#!/bin/sh
here=$(dirname "$0")
. "$OPENSPOT_SH"
data=$OPENSPOT_DATA
event=$(value event)
load=$(value event.value)

# Prints the block that the script of another spot prints as words named $1, without its root and its bar, with $2
# before its detail.
words() {
  name=$1
  label=$2
  shift 2
  "$@" | /usr/bin/sed -E -e '1,/^$/d' -e "s/^(graph|view|text|number)=.*/text=$name/" -e '/^value=/d' -e "s/^detail=/detail=$label/"
}

# Prints the text kept in file $1 of the data folder, or nothing.
kept() {
  [ -f "$data/$1" ] && /bin/cat "$data/$1"
}

# Prints the battery. A change of the power source reads it again.
battery() {
  if [ "$event" = power.change ] || [ ! -f "$data/battery" ]; then
    words battery 'Battery · ' "$here/../battery.spot/battery.sh" show | openspot_keep "$data/battery"
  fi
  kept battery
}

# Prints the device with the lowest battery. A device that connects reads them again, and so does a panel open after
# 5 minutes, since the Bluetooth report takes a second.
devices() {
  again=
  if [ "$event" = device.connect ] || [ ! -f "$data/devices" ]; then again=1
  elif [ "$event" = panel.open ] && [ $(($(/bin/date +%s) - $(/usr/bin/stat -f %m "$data/devices"))) -ge 300 ]; then again=1
  fi
  if [ -n "$again" ]; then
    words devices '' "$here/../devices.spot/devices.sh" show "$("$here/../devices.spot/devices.sh" levels)" | openspot_keep "$data/devices"
  fi
  kept devices
}

# Prints the use of all cores, with the trend of the last 30 points as bars. The load that Openspot measures every 5
# seconds adds a point. Until two points make a trend, it prints the last point, or the use measured now, as words.
cpu() {
  set -- $(kept trend)
  case $load in
    cpu=*)
      now=${load#cpu=}
      set -- "$@" "${now%% *}"
      [ $# -le 30 ] || shift $(($# - 30))
      printf '%s\n' "$@" | openspot_keep "$data/trend"
      ;;
  esac
  [ $# -gt 0 ] || set -- $(ps -A -o %cpu= | LC_ALL=C awk -v cores="$(/usr/sbin/sysctl -n hw.ncpu)" '{ sum += $1 } END { print int(sum / cores) }')
  eval "now=\${$#}"
  if [ $# -lt 2 ]; then
    printf 'text=cpu\ntitle=%s%%\ndetail=CPU\n' "$now"
    return
  fi
  printf 'graph=cpu\ntitle=%s%%\ndetail=CPU\nmax=100\n' "$now"
  for point; do printf 'value=%s\n' "$point"; done
}

# Prints the memory in use, as a percent, with a tone when little is left. The load gives it, and a read
# with no load measures it now.
memory() {
  case $load in
    *memory=*) used=${load##*memory=} used=${used%% *} ;;
    *) used=$((100 - $(/usr/sbin/sysctl -n kern.memorystatus_level))) ;;
  esac
  if [ "$used" -ge 95 ]; then detail="Memory almost full" tone=bad
  elif [ "$used" -ge 85 ]; then detail="Little memory left" tone=warn
  else detail="Memory" tone=
  fi
  printf 'text=memory\ntitle=%s%%\ndetail=%s\ntone=%s\n' "$used" "$detail" "$tone"
}

printf 'frame=\ngrid.wide=battery cpu\n'
printf 'grid.large=cpu cpu battery battery\ngrid.large=cpu cpu memory memory\ngrid.large=cpu cpu devices devices\n'
printf 'grid=cpu\ngrid=battery\ngrid=memory\ngrid=devices\n\n'
battery
printf '\n'
cpu
printf '\n'
memory
printf '\n'
devices
