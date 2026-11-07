#!/bin/sh
# name=System details
# symbol=gauge.with.dots.needle.50percent
# read=panel
# grid=false
here=$(dirname "$0")

# Prints the title that a metric script in this folder prints.
title() {
  "$here/$1" read | sed -n 's/^title=//p' | head -1
}

printf 'section=battery\ntitle=Battery\n\npart=mac\ntitle=This Mac\nsymbol=laptopcomputer\ndetail=%s\n\n' "$(title battery.sh)"
"$here/devices.sh" levels | awk -F'\t' '{
  printf "part=device-%d\ntitle=%s%s\nsymbol=%s\ndetail=%s%%\n\n", NR, $1, ($2 == "" ? "" : ", " tolower($2)), ($1 ~ /AirPods/ ? "airpods" : "headphones"), $3
}'

printf 'section=cpu\ntitle=CPU\n\npart=cpu-all\ntitle=All cores\nsymbol=cpu\ndetail=%s\n\n' "$(title cpu.sh)"
ps -Aco pcpu=,comm= -r | head -3 | awk '{
  cpu = $1; $1 = ""; sub(/^ /, "")
  printf "part=cpu-%d\ntitle=%s\ndetail=%s%%\n\n", NR, $0, cpu
}'

printf 'section=memory\ntitle=Memory\n\npart=memory-used\ntitle=Used\nsymbol=memorychip\ndetail=%s\n\n' "$(title memory.sh)"
printf 'part=swap\ntitle=Swap\ndetail=%s\n\n' "$(/usr/sbin/sysctl -n vm.swapusage | awk '{ mb = $6 + 0; print (mb >= 1024 ? sprintf("%.1f GB", mb / 1024) : sprintf("%d MB", mb)) }')"
ps -Aco rss=,comm= -m | head -3 | awk '{
  kb = $1; $1 = ""; sub(/^ /, "")
  printf "part=memory-%d\ntitle=%s\ndetail=%s\n\n", NR, $0, (kb >= 1048576 ? sprintf("%.1f GB", kb / 1048576) : sprintf("%d MB", kb / 1024))
}'
