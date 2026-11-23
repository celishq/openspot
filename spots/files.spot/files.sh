#!/bin/sh
. "$OPENSPOT_SH"
case "$1" in
  show | sheet.text)
    texts=$(value value; value alt)
    printf 'button=reveal\ntitle=Show in Finder\nshortcut=cmd+return\n\n'
    printf 'button=copy\ntitle=Copy path\nshortcut=cmd+shift+c\n\n'
    predicate=''
    while IFS= read -r text; do
      query=$(printf '%s' "$text" | tr -d '"\\*')
      [ "${#query}" -lt 2 ] && continue
      predicate="$predicate${predicate:+ || }kMDItemFSName == \"*$query*\"cd"
    done <<EOF
$texts
EOF
    [ -z "$predicate" ] && exit 0
    mdfind -onlyin "$HOME" "$predicate" 2>/dev/null \
      | grep -v "^$HOME/Library/" \
      | LC_ALL=C tr -d '\000-\011\013-\037' \
      | awk -F/ -v home="$HOME" '
          NR > 30 { exit }
          {
            folder = $0
            sub(/\/[^\/]*$/, "", folder)
            if (index(folder, home) == 1) folder = "~" substr(folder, length(home) + 1)
            printf "%s\t%s\t%s\t%s\n", $0, $NF, folder, $0
          }' \
      | openspot_items
    ;;
  reveal)
    open -R "$(value item)"
    ;;
  copy)
    value item | openspot clipboard copy
    openspot toast Copied
    ;;
  press)
    open "$(value item)"
    ;;
esac
