#!/bin/sh
# icon=/System/Applications/Shortcuts.app
# detail=Run a shortcut
# size=small
# read=panel
# global=true
# drop=*
. "$OPENSPOT_SH"
input="$OPENSPOT_DATA/input"
kept="$OPENSPOT_DATA/rows"
app=/System/Applications/Shortcuts.app

# Prints a row for each shortcut in a folder, or with "none" for each shortcut in no folder.
rows() {
  parent=''
  [ "$1" = none ] || parent="parent=$(esc "$1")"
  shortcuts list --folder-name "$1" | sed 's/\\/\\\\/g' | parent=$parent app=$app awk 'NF {
    printf "row=%s\ntitle=%s\nicon=%s\n", $0, $0, ENVIRON["app"]
    if (ENVIRON["parent"] != "") print ENVIRON["parent"]
    print ""
  }'
}

# Prints a row for each shortcut in no folder, then for each shortcut in each folder. It fails when Shortcuts gives no list.
all_rows() {
  folders=$(shortcuts list --folders) || return 1
  rows none
  printf '%s\n' "$folders" | while IFS= read -r folder; do
    [ -n "$folder" ] && rows "$folder"
  done
}

# Prints the head of the list: the files that the next run takes, when there are some, and the buttons.
head_of_list() {
  if [ -s "$input" ]; then
    count=$(wc -l <"$input" | tr -d ' ')
    if [ "$count" = 1 ]; then
      printf 'title=Run with %s\n' "$(esc "$(basename "$(cat "$input")")")"
    else
      printf 'title=Run with %s files\n' "$count"
    fi
    printf 'detail=Pick a shortcut\n\n'
    printf 'button=cancel\ntitle=Cancel\nshortcut=escape\nscope=command\n\n'
  fi
  printf 'button=open\ntitle=Run\n\n'
  printf 'button=clipboard\ntitle=Run with clipboard\nshortcut=cmd+return\nclose=true\n\n'
  printf 'button=edit\ntitle=Open in Shortcuts\nshortcut=cmd+e\nclose=true\n\n'
}

# Runs a shortcut with each file as its input, copies its result, and says what happened.
run() {
  name=$1
  shift
  out="$(mktemp -d)/result"
  for path; do
    set -- "$@" -i "$path"
    shift
  done
  if ! shortcuts run "$name" "$@" -o "$out" </dev/null >/dev/null; then
    printf '%s stopped before it finished. Open it in Shortcuts to see which step failed.\n' "$name" >&2
    printf 'link=shortcuts://open-shortcut?name=%s\n' "$(jq -rn --arg name "$name" '$name | @uri')"
    exit 1
  fi
  if [ ! -s "$out" ]; then
    printf 'toast=Ran %s.\n' "$(esc "$name")"
    return
  fi
  case $(file -b --mime-type "$out") in
    text/*)
      openspot clipboard copy <"$out" || exit 1
      ;;
    *)
      kind=$(file -b --extension "$out")
      file="$(dirname "$out")/$(printf '%s' "$name" | tr / -)"
      [ "$kind" = '???' ] || file="$file.${kind%%/*}"
      mv "$out" "$file"
      openspot clipboard copy "$file" || exit 1
      ;;
  esac
  printf 'toast=Copied the result of %s.\n' "$(esc "$name")"
}

case "$1" in
  read)
    [ "$OPENSPOT_REASON" = panel ] && rm -f "$input"
    head_of_list
    if [ -s "$kept" ]; then
      cat "$kept"
      echo ---
      fresh=$(all_rows) || exit 0
      [ "$fresh" = "$(cat "$kept")" ] && exit 0
      head_of_list
    else
      fresh=$(all_rows) || exit 0
    fi
    printf '%s\n' "$fresh"
    printf '%s\n' "$fresh" >"$kept.$$" && mv "$kept.$$" "$kept"
    ;;
  open)
    name=$2
    set --
    if [ -s "$input" ]; then
      taken=$(mktemp)
      mv "$input" "$taken"
      while IFS= read -r path; do set -- "$@" "$path"; done <"$taken"
    fi
    run "$name" "$@"
    ;;
  clipboard)
    text="$(mktemp -d)/clipboard.txt"
    pbpaste >"$text"
    run "$2" "$text"
    ;;
  edit)
    shortcuts view "$2"
    ;;
  drop)
    shift
    printf '%s\n' "$@" >"$input.tmp" && mv "$input.tmp" "$input"
    ;;
  cancel)
    rm -f "$input"
    ;;
esac
