#!/bin/sh
# name=System details
# symbol=gauge.with.dots.needle.50percent
# read=panel
# grid=false
here=$(dirname "$0")
cpu=$("$here/cpu.sh" read)
battery=$("$here/battery.sh" read)
devices=$("$here/devices.sh" levels | awk -F'\t' '$2 != "Case" && (!($1 in low) || $3 + 0 < low[$1] + 0) { low[$1] = $3 } END { for (name in low) printf "%s\t%s\n", name, low[name] }')

# Prints the value of one key from the text on stdin.
value() {
  sed -n "s/^$1=//p" | head -1
}

# Prints a level from 0 to 1 as a whole percent.
percent() {
  awk -v v="${1:-0}" 'BEGIN { printf "%d", v * 100 }'
}

{
  printf 'grid=c c m m\ngrid=c c m m\ngrid=h h h h\ngrid=h h h h\n'
  printf '%s\n' "$devices" | awk -F'\t' 'BEGIN { split("e f g i j k", letter, " ") }
    NF { n++ }
    END {
      cells[1] = "b"
      for (i = 1; i <= n; i++) cells[i + 1] = letter[i]
      for (i = 1; i <= n + 1; i += 2) {
        line = cells[i] " " cells[i] " " (i <= n ? cells[i + 1] " " cells[i + 1] : ". .")
        printf "grid=%s\ngrid=%s\n", line, line
      }
    }'
  printf 'grid=x x x x\ngrid=x x x x\ngrid=x x x x\n'
}

printf '\npart=cpu\ncell=c\ntitle=CPU\nmetric=%s\n' "$(printf '%s\n' "$cpu" | value title)"
printf '\npart=history\ncell=h\n'
printf '%s\n' "$cpu" | grep '^point='
printf '\npart=memory\ncell=m\ntitle=Memory\nmetric=%s\n' "$("$here/memory.sh" read | value title)"
printf '\npart=mac\ncell=b\nblock=progress\ntitle=Mac\ndetail=%s\nlevel=%s\n' "$(printf '%s\n' "$battery" | value title)" "$(percent "$(printf '%s\n' "$battery" | value value)")"
printf '%s\n' "$devices" | awk -F'\t' 'BEGIN { split("e f g i j k", letter, " ") }
  NF {
    n++
    split($1, word, " ")
    printf "\npart=device-%d\ncell=%s\nblock=progress\ntitle=%s\ndetail=%s%%\nlevel=%s\n", n, letter[n], word[1], $2, $2
  }'

top=$(
  echo "Top CPU"
  ps -Aco pcpu=,comm= -r | head -3 | awk '{ cpu = $1; $1 = ""; sub(/^ /, ""); printf "%s  %s%%\n", $0, cpu }'
  echo
  echo "Top memory"
  ps -Aco rss=,comm= -m | head -3 | awk '{ kb = $1; $1 = ""; sub(/^ /, ""); printf "%s  %s\n", $0, (kb >= 1048576 ? sprintf("%.1f GB", kb / 1048576) : sprintf("%d MB", kb / 1024)) }'
)
printf '\npart=top\ncell=x\nreadonly=true\ntext=%s\n' "$(printf '%s' "$top" | awk '{ printf "%s%s", (NR > 1 ? "\\n" : ""), $0 }')"
