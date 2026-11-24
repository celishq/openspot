#!/bin/sh
export LC_ALL=en_US.UTF-8
data="$OPENSPOT_DATA/snippets.json"
. "$OPENSPOT_SH"

# Makes a jq value safe for one line of a text block.
esc='def esc: gsub("\\\\"; "\\\\") | gsub("\n"; "\\n");'

load() {
  if [ -s "$data" ]; then cat "$data"; else echo '[]'; fi
}

store() {
  cat > "$data.$$" && mv "$data.$$" "$data"
}

content() {
  load | jq -e -j --arg id "$1" '.[] | select(.id == $id) | .content' || {
    echo "This snippet is gone." >&2
    exit 1
  }
}

# Prints the form with this title and these values.
form() {
  jq -nr --arg title "$1" --argjson v "$2" "$esc"'"frame=\ntype=form\ntitle=\($title)

field=title
title=Name
value=\($v.title | esc)
required=true

field=content
title=Text
type=multiline
value=\($v.content | esc)
required=true"'
}

item=$(value item)

case "$1" in
  show)
    printf 'button=press\ntitle=Copy\n\n'
    printf 'button=paste\ntitle=Paste\nshortcut=cmd+return\n\n'
    printf 'button=edit\ntitle=Edit\nshortcut=cmd+e\nclose=false\n\n'
    printf 'button=delete\ntitle=Delete\nshortcut=cmd+backspace\nconfirm=Press again to delete\nclose=false\n\n'
    printf 'button=new\ntitle=New snippet\nshortcut=cmd+n\nscope=spot\nclose=false\nplaceholder=Text to keep\n\n'
    [ -s "$data" ] || exit 0
    jq -r "$esc"'.[] | "item=\(.id | esc)\ntitle=\(.title | esc)\ndetail=\(.content | gsub("\\s+"; " ") | .[0:200] | esc)\n"' "$data"
    ;;
  new)
    title=$(value input.title)
    text=$(value input.content; printf x)
    # Asks with its own form, filled with what the call gave, until both the name and the text are given.
    if [ -z "$title" ] || [ -z "${text%x}" ]; then
      form "New snippet" "$(jq -nc --arg title "$title" --arg content "${text%x}" '{$title, $content}')"
      exit 0
    fi
    id=$(uuidgen)
    load | jq -c --arg id "$id" --arg title "$title" --arg content "${text%x}" '. + [{id: $id, title: $title, content: $content}]' | store
    openspot select "$id"
    ;;
  edit)
    title=$(value input.title)
    text=$(value input.content; printf x)
    if [ -z "$title${text%x}" ]; then
      form "Edit snippet" "$(load | jq -c --arg id "$item" '.[] | select(.id == $id)')"
      exit 0
    fi
    load | jq -c --arg id "$item" --arg title "$title" --arg content "${text%x}" 'map(if .id == $id then .title = $title | .content = $content else . end)' | store
    openspot select "$item"
    ;;
  delete)
    load | jq -c --arg id "$item" 'map(select(.id != $id))' | store
    ;;
  paste)
    text=$(content "$item" && printf x) || exit 1
    previous=$(openspot clipboard read; printf x)
    printf '%s' "${text%x}" | openspot clipboard copy
    openspot clipboard paste || exit 1
    sleep 0.3
    if [ "$previous" != x ]; then
      printf '%s' "${previous%x}" | openspot clipboard copy
    fi
    ;;
  press)
    text=$(content "$item" && printf x) || exit 1
    printf '%s' "${text%x}" | openspot clipboard copy
    openspot toast Copied
    ;;
esac
