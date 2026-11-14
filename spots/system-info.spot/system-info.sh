#!/bin/sh
# title=System details
# icon=gauge.with.dots.needle.50percent
# on=sheet.open
# preview=sample
# offers=card
if [ "$OPENSPOT_REASON" = spot.preview ]; then
  printf 'section=battery\ntitle=Battery\n\ntext=mac\ntitle=This Mac\nicon=macbook\ndetail=84%%\nvalue=0.84\n\n'
  printf 'text=device-1\ntitle=AirPods Pro, left\ndetail=72%%\nicon=airpodpro.left\nvalue=0.72\n\n'
  printf 'text=device-2\ntitle=AirPods Pro, right\ndetail=68%%\nicon=airpodpro.right\nvalue=0.68\n\n'
  printf 'text=device-3\ntitle=Magic Keyboard\ndetail=15%%\nicon=keyboard\nvalue=0.15\ntone=bad\n\n'
  printf 'section=cpu\ntitle=CPU\n\ntext=cpu-all\ntitle=All cores\nicon=cpu\ndetail=23%%\nmax=100\n'
  for v in 12 18 15 22 31 27 19 24 35 28 21 17 26 33 29 23; do printf 'value=%s\n' "$v"; done
  printf '\ntext=cpu-1\ntitle=Safari\ndetail=18.4%%\n\ntext=cpu-2\ntitle=Music\ndetail=6.2%%\n\ntext=cpu-3\ntitle=WindowServer\ndetail=4.9%%\n\n'
  printf 'section=memory\ntitle=Memory\n\ntext=memory-used\ntitle=Used\nicon=memorychip\ndetail=61%%\nvalue=0.61\n\n'
  printf 'text=swap\ntitle=Swap\ndetail=512 MB\n\n'
  printf 'text=memory-1\ntitle=Safari\ndetail=1.2 GB\n\ntext=memory-2\ntitle=Mail\ndetail=486 MB\n\ntext=memory-3\ntitle=Music\ndetail=312 MB\n'
  exit 0
fi
here=$(dirname "$0")
. "$OPENSPOT_SH"

# Prints what a metric script in the spot folder beside this one shows as the value and the mark of a line. It looks, and
# does not read, so that the trend of a metric gets no point from it.
reading() {
  "$here/../${1%.sh}.spot/$1" show | sed -En 's/^title=/detail=/p; /^(value|max|tone)=./p'
}

printf 'section=battery\ntitle=Battery\n\ntext=mac\ntitle=This Mac\nicon=macbook\n%s\n\n' "$(reading battery.sh)"
"$here/../devices.spot/devices.sh" levels | awk -F'\t' '
function symbol(name, part) {
  if (name ~ /AirPods Max/) return "airpodsmax"
  if (name ~ /AirPods Pro/) return part == "Case" ? "airpodspro.chargingcase.wireless" : part == "" ? "airpodspro" : "airpodpro." tolower(part)
  if (name ~ /AirPods/) return part == "Case" ? "airpods.chargingcase" : part == "" ? "airpods" : "airpod." tolower(part)
  if (name ~ /Keyboard/) return "keyboard"
  if (name ~ /Mouse/) return "magicmouse"
  return "headphones"
}
{
  printf "device-%d\t%s%s\t%s%%\t%s\tvalue=%.2f\t%s\n", NR, $1, ($2 == "" ? "" : ", " tolower($2)), $3, symbol($1, $2), $3 / 100, ($3 <= 20 ? "tone=bad" : "")
}' | openspot_rows text

printf 'section=cpu\ntitle=CPU\n\ntext=cpu-all\ntitle=All cores\nicon=cpu\n%s\n\n' "$(reading cpu.sh)"
ps -Aco pcpu=,comm= -r | head -3 | awk '{
  cpu = $1; $1 = ""; sub(/^ /, "")
  printf "cpu-%d\t%s\t%s%%\n", NR, $0, cpu
}' | openspot_rows text

printf 'section=memory\ntitle=Memory\n\ntext=memory-used\ntitle=Used\nicon=memorychip\n%s\n\n' "$(reading memory.sh)"
printf 'text=swap\ntitle=Swap\ndetail=%s\n\n' "$(/usr/sbin/sysctl -n vm.swapusage | awk '{ mb = $6 + 0; print (mb >= 1024 ? sprintf("%.1f GB", mb / 1024) : sprintf("%d MB", mb)) }')"
ps -Aco rss=,comm= -m | head -3 | awk '{
  kb = $1; $1 = ""; sub(/^ /, "")
  printf "memory-%d\t%s\t%s\n", NR, $0, (kb >= 1048576 ? sprintf("%.1f GB", kb / 1048576) : sprintf("%d MB", kb / 1024))
}' | openspot_rows text
