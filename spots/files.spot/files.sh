#!/bin/sh
# icon=doc.text.magnifyingglass
# detail=Find a file
# on=sheet.open
# on=sheet.text
# uses=clipboard
# preview=sample
# offers=card
if [ "$OPENSPOT_REASON" = spot.preview ]; then
  printf 'button=reveal\ntitle=Show in Finder\nshortcut=cmd+return\nclose=true\n\n'
  printf 'button=copy\ntitle=Copy path\nshortcut=cmd+shift+c\nclose=true\n\n'
  for file in 'Documents/Report.pages' 'Documents/Work/Report 2026.key' 'Desktop/report-draft.txt' 'Documents/Taxes/Report Q3.numbers' 'Downloads/report-summary.rtf' 'Documents/Work/Report notes.md'; do
    printf 'row=/Users/you/%s\ntitle=%s\ndetail=~/%s\nicon=/Users/you/%s\n\n' "$file" "${file##*/}" "${file%/*}" "$file"
  done
  exit 0
fi
texts=$(sed -n 's/^search=//p; s/^form=//p')
. "$OPENSPOT_SH"
case "$1" in
  read)
    printf 'button=reveal\ntitle=Show in Finder\nshortcut=cmd+return\nclose=true\n\n'
    printf 'button=copy\ntitle=Copy path\nshortcut=cmd+shift+c\nclose=true\n\n'
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
      | openspot_rows
    ;;
  reveal)
    open -R "$2"
    ;;
  copy)
    printf '%s' "$2" | openspot clipboard copy
    echo "toast=Copied"
    ;;
  open)
    open "$2"
    ;;
esac
