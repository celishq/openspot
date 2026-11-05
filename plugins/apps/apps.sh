#!/bin/sh
case "$1" in
  items)
    {
      find /Applications /System/Applications "$HOME/Applications" -maxdepth 3 -name '*.app' -prune 2>/dev/null
      echo /System/Library/CoreServices/Finder.app
    } | sed 's/\\/\\\\/g' \
      | awk -F/ '{ name = $NF; sub(/\.app$/, "", name); print name "\t" $0 }' \
      | sort -f -u \
      | awk -F'\t' '{ printf "title=%s\nrun=%s\nfile=%s\n\n", $1, $2, $2 }'
    ;;
  reveal)
    open -R "$2"
    ;;
  *)
    open "$1"
    ;;
esac
