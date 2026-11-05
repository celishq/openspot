#!/bin/sh
# symbol=doc.text.magnifyingglass
# subtitle=Find a file
# key=f
# read=click
# search=live
case "$1" in
  ""|search)
    printf 'action=reveal\ntitle=Show in Finder\nkey=cmd+return\nclose=true\n\n'
    printf 'action=copy\ntitle=Copy path\nkey=cmd+shift+c\nclose=true\n\n'
    query=$(printf '%s' "$2" | tr -d '"\\*')
    [ "${#query}" -lt 2 ] && exit 0
    mdfind -onlyin "$HOME" "kMDItemFSName == \"*$query*\"cd" 2>/dev/null \
      | grep -v "^$HOME/Library/" \
      | LC_ALL=C tr -d '\000-\011\013-\037' \
      | sed 's/\\/\\\\/g' \
      | awk -F/ -v home="$HOME" '
          NR > 30 { exit }
          {
            folder = $0
            sub(/\/[^\/]*$/, "", folder)
            if (index(folder, home) == 1) folder = "~" substr(folder, length(home) + 1)
            printf "row=%s\ndetail=%s\nrun=%s\nfile=%s\n\n", $NF, folder, $0, $0
          }'
    ;;
  reveal)
    open -R "$2"
    ;;
  copy)
    printf '%s' "$2" | LC_ALL=en_US.UTF-8 pbcopy
    ;;
  open)
    open "$2"
    ;;
esac
