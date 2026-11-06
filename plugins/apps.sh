#!/bin/sh
# symbol=square.grid.2x2
# subtitle=Open app
# key=a
# read=panel
# rank=2
case "$1" in
  read)
    printf 'action=reveal\ntitle=Show in Finder\nkey=cmd+return\nclose=true\n\n'
    {
      find /Applications /System/Applications "$HOME/Applications" -maxdepth 3 -name '*.app' -prune 2>/dev/null
      echo /System/Library/CoreServices/Finder.app
    } | sed 's/\\/\\\\/g' \
      | awk -F/ '{ name = $NF; sub(/\.app$/, "", name); print name "\t" $0 }' \
      | sort -f -u \
      | awk -F'\t' '{ printf "row=%s\nrun=%s\nfile=%s\n\n", $1, $2, $2 }'
    ;;
  reveal)
    open -R "$2"
    ;;
  open)
    open "$2"
    ;;
esac
