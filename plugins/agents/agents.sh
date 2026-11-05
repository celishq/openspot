#!/bin/sh
[ "$1" = metric ] || exit 1
export LC_ALL=en_US.UTF-8

# Prints one line for each agent: its tool, then the folder it works in.
sessions() {
  for tool in claude codex; do
    for pid in $(pgrep -x "$tool"); do
      folder=$(/usr/sbin/lsof -a -p "$pid" -d cwd -Fn 2>/dev/null | sed -n 's/^n//p')
      printf '%s\t%s\n' "$tool" "$(basename "${folder:-?}")"
    done
  done
}

list=$(sessions)
count=$(printf '%s' "$list" | grep -c .)
case "$2" in
  running)
    word=agents
    [ "$count" = 1 ] && word=agent
    printf '{"title":"%s","detail":"%s running","symbol":"sparkles"}\n' "$count" "$word"
    ;;
  list)
    rows=$(printf '%s' "$list" | jq -R -s -c 'split("\n") | map(select(length > 0) | split("\t") | {title: .[1], detail: .[0]})')
    printf '{"title":"Agents","rows":%s}\n' "$rows"
    ;;
  *) exit 1 ;;
esac
