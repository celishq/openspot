#!/bin/sh
# symbol=doc.text.magnifyingglass
# subtitle=Find a file
# key=f
# read=sheet
case "$1" in
  read)
    printf 'search=script\n\n'
    printf 'button=reveal\ntitle=Show in Finder\nkey=cmd+return\nclose=true\n\n'
    printf 'button=copy\ntitle=Copy path\nkey=cmd+shift+c\nclose=true\n\n'
    shift
    predicate=''
    for text in "$@"; do
      query=$(printf '%s' "$text" | tr -d '"\\*')
      [ "${#query}" -lt 2 ] && continue
      predicate="$predicate${predicate:+ || }kMDItemFSName == \"*$query*\"cd"
    done
    [ -z "$predicate" ] && exit 0
    mdfind -onlyin "$HOME" "$predicate" 2>/dev/null \
      | grep -v "^$HOME/Library/" \
      | LC_ALL=C tr -d '\000-\011\013-\037' \
      | sed 's/\\/\\\\/g' \
      | awk -F/ -v home="$HOME" '
          NR > 30 { exit }
          {
            folder = $0
            sub(/\/[^\/]*$/, "", folder)
            if (index(folder, home) == 1) folder = "~" substr(folder, length(home) + 1)
            printf "row=%s\ntitle=%s\ndetail=%s\nfile=%s\n\n", $0, $NF, folder, $0
          }'
    ;;
  reveal)
    open -R "$2"
    ;;
  copy)
    printf '%s' "$2" | LC_ALL=en_US.UTF-8 pbcopy
    echo "toast=Copied"
    ;;
  open)
    open "$2"
    ;;
esac
