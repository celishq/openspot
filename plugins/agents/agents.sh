#!/bin/sh
[ "$1" = metric ] || exit 1
export LC_ALL=en_US.UTF-8

# Prints one line for each agent in a terminal: its tool, then the folder it works in.
sessions() {
  ps -axo pid=,tty=,args= | awk '$2 != "??" && $4 !~ /^(--)?bg-/ {
    if ($3 ~ /(^|\/)claude$/ || $3 ~ /\/claude\/versions\//) print $1, "claude"
    else if ($3 ~ /(^|\/)codex$/ || ($3 ~ /(^|\/)node$/ && $4 ~ /codex/)) print $1, "codex"
  }' | while read -r pid tool; do
    folder=$(/usr/sbin/lsof -a -p "$pid" -d cwd -Fn 2>/dev/null | sed -n 's/^n//p')
    printf '%s\t%s\n' "$tool" "$(basename "${folder:-?}")"
  done
}

list=$(sessions)
count=$(printf '%s' "$list" | grep -c .)
case "$2" in
  running)
    printf '{"title":"%s","detail":"running","symbol":"sparkles"}\n' "$count"
    ;;
  list)
    rows=$(printf '%s' "$list" | jq -R -s -c 'split("\n") | map(select(length > 0) | split("\t") | {title: .[1], detail: .[0]})')
    printf '{"title":"%s","rows":%s}\n' "$count" "$rows"
    ;;
  *) exit 1 ;;
esac
