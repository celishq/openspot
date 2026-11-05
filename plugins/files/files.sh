#!/bin/sh
case "$1" in
  items)
    query=$(printf '%s' "$2" | tr -d '"\\*')
    [ "${#query}" -lt 2 ] && exit 0
    mdfind -onlyin "$HOME" "kMDItemFSName == \"*$query*\"cd" 2>/dev/null \
      | grep -v "^$HOME/Library/" \
      | LC_ALL=C tr -d '\000-\011\013-\037' \
      | sed 's/\\/\\\\/g; s/"/\\"/g' \
      | awk -F/ -v home="$HOME" '
          NR > 30 { exit }
          {
            folder = $0
            sub(/\/[^\/]*$/, "", folder)
            if (index(folder, home) == 1) folder = "~" substr(folder, length(home) + 1)
            printf "{\"title\":\"%s\",\"subtitle\":\"%s\",\"run\":\"%s\",\"file\":\"%s\"}\n", $NF, folder, $0, $0
          }'
    ;;
  reveal)
    open -R "$2"
    ;;
  copy)
    printf '%s' "$2" | LC_ALL=en_US.UTF-8 pbcopy
    ;;
  *)
    open "$1"
    ;;
esac
