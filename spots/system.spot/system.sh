#!/bin/sh
here=$(dirname "$0")
. "$OPENSPOT_SH"
data=$OPENSPOT_DATA
event=$1

# A row of a device opens the Bluetooth settings, and a row of a process or the swap opens Activity Monitor.
case $1 in
  show | system.load | power.change | device.connect) ;;
  press)
    case $(value item) in
      device-*) open "x-apple.systempreferences:com.apple.BluetoothSettings" ;;
      *) open -a "Activity Monitor" ;;
    esac
    exit 0
    ;;
  *) exit 0 ;;
esac
load=$(value value)

# Prints the number that the script of another spot prints, named $1, without its root, its classes and its type.
borrowed() {
  name=$1
  shift
  "$@" | /usr/bin/sed -E -e '1,/^$/d' -e '/^(class|type)=/d' -e "s/^number=.*/number=$name/"
}

# Prints the number block on stdin inside the gauges twice: as a ring with the classes $1, and as a bar with the
# classes $2, named with -bar after it. Each place shows one of them.
gauge() {
  /usr/bin/awk -v ring="$1" -v bar="$2" '
    NF { lines[++count] = $0 }
    END {
      for (i = 1; i <= count; i++) { print lines[i]; if (i == 1) { print "parent=gauges"; print "type=ring"; print "class=" ring } }
      print ""
      for (i = 1; i <= count; i++) {
        line = lines[i]
        if (i == 1) sub(/$/, "-bar", line)
        print line
        if (i == 1) { print "parent=gauges"; print "type=bar"; print "class=" bar }
      }
    }'
}

# Prints the text kept in file $1 of the data folder, or nothing.
kept() {
  [ -f "$data/$1" ] && /bin/cat "$data/$1"
}

# Prints the battery. A change of the power source reads it again.
battery() {
  if [ "$event" = power.change ] || [ ! -f "$data/battery.number" ]; then
    borrowed battery "$here/../battery.spot/battery.sh" show | openspot_keep "$data/battery.number"
  fi
  kept battery.number
}

# Prints the device with the lowest battery, and keeps the level of each device for its rows. A device that connects
# reads them again, and so does a show after 5 minutes, since the Bluetooth report takes a second.
devices() {
  again=
  if [ "$event" = device.connect ] || [ ! -f "$data/devices.number" ]; then again=1
  elif [ "$event" = show ] && [ $(($(/bin/date +%s) - $(/usr/bin/stat -f %m "$data/devices.number"))) -ge 300 ]; then again=1
  fi
  if [ -n "$again" ]; then
    "$here/../devices.spot/devices.sh" levels | openspot_keep "$data/devices.levels"
    borrowed devices "$here/../devices.spot/devices.sh" show "$(kept devices.levels)" | openspot_keep "$data/devices.number"
  fi
  kept devices.number
}

# Prints the use of all cores, the last of the trend of the last 30 points. The load that Openspot measures every 5
# seconds adds a point, and a read before the first point measures the use now.
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
  for last; do :; done
  printf 'number=cpu\ntitle=CPU\nmax=100\nunit=%%\nvalue=%s\n' "$last"
}

# Prints the memory in use, as a percent, with a tone when little is left. The load gives it, and a read
# with no load measures it now.
memory() {
  case $load in
    *memory=*) used=${load##*memory=} used=${used%% *} ;;
    *) used=$((100 - $(/usr/sbin/sysctl -n kern.memorystatus_level))) ;;
  esac
  if [ "$used" -ge 95 ]; then detail="Almost full" tone=bad
  elif [ "$used" -ge 85 ]; then detail="Little left" tone=warn
  else detail= tone=
  fi
  printf 'number=memory\ntitle=Memory\nvalue=%s\nmax=100\nunit=%%\ndetail=%s\ntone=%s\n' "$used" "$detail" "$tone"
}

# Prints a row for each device and each part of it, such as the case of AirPods, with its level as a ring.
device_rows() {
  [ -s "$data/devices.levels" ] || return 0
  printf 'box=bluetooth\nparent=list\ntitle=Devices\n'
  kept devices.levels | awk -F'\t' '
  function symbol(name, part) {
    if (name ~ /AirPods Max/) return "airpodsmax"
    if (name ~ /AirPods Pro/) return part == "Case" ? "airpodspro.chargingcase.wireless" : part == "" ? "airpodspro" : "airpodpro." tolower(part)
    if (name ~ /AirPods/) return part == "Case" ? "airpods.chargingcase" : part == "" ? "airpods" : "airpod." tolower(part)
    if (name ~ /Keyboard/) return "keyboard"
    if (name ~ /Mouse/) return "magicmouse"
    return "headphones"
  }
  NF {
    printf "device-%d\t%s%s\t\t%s\tvalue=%d\tmax=100\ttype=ring\tunit=%%\topen.title=Bluetooth Settings\tparent=bluetooth\t%s\n", NR, $1, ($2 == "" ? "" : ", " tolower($2)), symbol($1, $2), $3, ($3 <= 20 ? "tone=bad" : "")
  }' | openspot_items number
}

# Prints the three processes that use the most CPU, and the three that hold the most memory with the swap.
process_rows() {
  printf 'box=top-cpu\nparent=list\ntitle=CPU\n'
  ps -Aco pcpu=,comm= -r | head -3 | awk '{
    cpu = $1; $1 = ""; sub(/^ /, "")
    printf "cpu-%d\t%s\t\t\tvalue=%s\tunit=%%\topen.title=Activity Monitor\tparent=top-cpu\n", NR, $0, cpu
  }' | openspot_items number
  printf 'box=top-memory\nparent=list\ntitle=Memory\n\nnumber=swap\nparent=top-memory\ntitle=Swap\n%s\nopen.title=Activity Monitor\n\n' "$(/usr/sbin/sysctl -n vm.swapusage | awk '{ mb = $6 + 0; printf "value=%d\ndisplay=%s", mb, (mb >= 1024 ? sprintf("%.1f GB", mb / 1024) : sprintf("%d MB", mb)) }')"
  ps -Aco rss=,comm= -m | head -3 | awk '{
    kb = $1; $1 = ""; sub(/^ /, "")
    printf "memory-%d\t%s\t\t\tvalue=%d\tdisplay=%s\topen.title=Activity Monitor\tparent=top-memory\n", NR, $0, kb, (kb >= 1048576 ? sprintf("%.1f GB", kb / 1048576) : sprintf("%d MB", kb / 1024))
  }' | openspot_items number
}

printf 'frame=\nclass=gap-part\nvalue=cpu\n\nbox=gauges\nclass=grid grid-cols-4 gap-part wide:grow square:grow strip:grow large:grow wide:flex-row wide:justify-between square:grid-cols-2 strip:grid-cols-2 large:grid-cols-2\n\n'
battery | gauge 'sheet:h-20 wide:aspect-square large:row-span-3 strip:hidden' 'hidden strip:flex'
printf '\n'
cpu | gauge 'sheet:h-20 wide:aspect-square large:hidden strip:hidden' 'hidden large:flex strip:flex'
printf '\n'
memory | gauge 'sheet:h-20 wide:hidden square:hidden strip:hidden large:hidden' 'hidden large:flex'
printf '\n'
devices | gauge 'sheet:h-20 wide:hidden square:hidden strip:hidden large:hidden' 'hidden large:flex'
printf '\nitems=list\nclass=wide:hidden square:hidden strip:hidden large:hidden\n\n'
device_rows
process_rows
