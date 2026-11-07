#!/bin/sh
# name=System details
# symbol=gauge.with.dots.needle.50percent
# read=panel
# grid=false
here=$(dirname "$0")

# Prints what a metric script in this folder reads as the value and the mark of a line.
reading() {
  "$here/$1" read | sed -En 's/^title=/detail=/p; /^(value|point|max|tone)=./p'
}

printf 'section=battery\ntitle=Battery\n\npart=mac\ntitle=This Mac\nsymbol=macbook\n%s\n\n' "$(reading battery.sh)"
"$here/devices.sh" levels | awk -F'\t' '
function symbol(name, part) {
  if (name ~ /AirPods Max/) return "airpodsmax"
  if (name ~ /AirPods Pro/) return part == "Case" ? "airpodspro.chargingcase.wireless" : part == "" ? "airpodspro" : "airpodpro." tolower(part)
  if (name ~ /AirPods/) return part == "Case" ? "airpods.chargingcase" : part == "" ? "airpods" : "airpod." tolower(part)
  if (name ~ /Keyboard/) return "keyboard"
  if (name ~ /Mouse/) return "magicmouse"
  return "headphones"
}
{
  printf "part=device-%d\ntitle=%s%s\nsymbol=%s\ndetail=%s%%\nvalue=%.2f\n", NR, $1, ($2 == "" ? "" : ", " tolower($2)), symbol($1, $2), $3, $3 / 100
  if ($3 <= 20) print "tone=bad"
  print ""
}'

printf 'section=cpu\ntitle=CPU\n\npart=cpu-all\ntitle=All cores\nsymbol=cpu\n%s\n\n' "$(reading cpu.sh | grep -v '^max=')"
ps -Aco pcpu=,comm= -r | head -3 | awk '{
  cpu = $1; $1 = ""; sub(/^ /, "")
  printf "part=cpu-%d\ntitle=%s\ndetail=%s%%\n\n", NR, $0, cpu
}'

printf 'section=memory\ntitle=Memory\n\npart=memory-used\ntitle=Used\nsymbol=memorychip\n%s\n\n' "$(reading memory.sh)"
printf 'part=swap\ntitle=Swap\ndetail=%s\n\n' "$(/usr/sbin/sysctl -n vm.swapusage | awk '{ mb = $6 + 0; print (mb >= 1024 ? sprintf("%.1f GB", mb / 1024) : sprintf("%d MB", mb)) }')"
ps -Aco rss=,comm= -m | head -3 | awk '{
  kb = $1; $1 = ""; sub(/^ /, "")
  printf "part=memory-%d\ntitle=%s\ndetail=%s\n\n", NR, $0, (kb >= 1048576 ? sprintf("%.1f GB", kb / 1048576) : sprintf("%d MB", kb / 1024))
}'
