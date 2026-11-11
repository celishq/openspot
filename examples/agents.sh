#!/bin/sh
# icon=sparkles
# read=5
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

sessions | sed 's/\\/\\\\/g' | awk -F'\t' 'NF { printf "row=%s\ndetail=%s\n\n", $2, $1 }'
