#!/bin/sh
# title=System details
# icon=gauge.with.dots.needle.50percent
# read=sheet
here=$(dirname "$0")

# Prints what a metric script in this folder shows as the value and the mark of a line. It looks, and does not read, so
# that the trend of a metric gets no point from it.
reading() {
  "$here/$1" show | sed -En 's/^title=/detail=/p; /^(value|max|tone)=./p'
}

printf 'section=battery\ntitle=Battery\n\ntext=mac\ntitle=This Mac\nicon=macbook\n%s\n\n' "$(reading battery.sh)"
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
  printf "text=device-%d\ntitle=%s%s\nicon=%s\ndetail=%s%%\nvalue=%.2f\n", NR, $1, ($2 == "" ? "" : ", " tolower($2)), symbol($1, $2), $3, $3 / 100
  if ($3 <= 20) print "tone=bad"
  print ""
}'

printf 'section=cpu\ntitle=CPU\n\ntext=cpu-all\ntitle=All cores\nicon=cpu\n%s\n\n' "$(reading cpu.sh)"
ps -Aco pcpu=,comm= -r | head -3 | awk '{
  cpu = $1; $1 = ""; sub(/^ /, "")
  printf "text=cpu-%d\ntitle=%s\ndetail=%s%%\n\n", NR, $0, cpu
}'

printf 'section=memory\ntitle=Memory\n\ntext=memory-used\ntitle=Used\nicon=memorychip\n%s\n\n' "$(reading memory.sh)"
printf 'text=swap\ntitle=Swap\ndetail=%s\n\n' "$(/usr/sbin/sysctl -n vm.swapusage | awk '{ mb = $6 + 0; print (mb >= 1024 ? sprintf("%.1f GB", mb / 1024) : sprintf("%d MB", mb)) }')"
ps -Aco rss=,comm= -m | head -3 | awk '{
  kb = $1; $1 = ""; sub(/^ /, "")
  printf "text=memory-%d\ntitle=%s\ndetail=%s\n\n", NR, $0, (kb >= 1048576 ? sprintf("%.1f GB", kb / 1048576) : sprintf("%d MB", kb / 1024))
}'
