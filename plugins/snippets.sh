#!/bin/sh
# symbol=text.quote
# subtitle=Copy text
# key=n
# size=small
# read=panel
# global=true
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
  jq -nr --arg title "$1" --argjson v "$2" "$esc"'"title=\($title)

field=title
title=Name
text=\($v.title | esc)
required=true

field=content
title=Text
type=multiline
text=\($v.content | esc)
required=true"'
}

case "$1" in
  read)
    printf 'button=open\ntitle=Copy\n\n'
    printf 'button=paste\ntitle=Paste\nkey=cmd+return\nclose=true\n\n'
    printf 'button=edit\ntitle=Edit\nkey=cmd+e\nform=true\n\n'
    printf 'button=delete\ntitle=Delete\nkey=cmd+backspace\nconfirm=Press again to delete\n\n'
    printf 'button=new\ntitle=New snippet\nkey=cmd+n\nscope=command\nform=true\n\n'
    load | jq -r "$esc"'.[] | "row=\(.title | esc)\ndetail=\(.content | gsub("\\s+"; " ") | .[0:200] | esc)\nrun=\(.id | esc)\n"'
    ;;
  new)
    title=$(value title)
    text=$(value content; printf x)
    if [ -z "$title${text%x}" ]; then
      form "New snippet" '{"title":"","content":""}'
      exit 0
    fi
    id=$(uuidgen)
    load | jq -c --arg id "$id" --arg title "$title" --arg content "${text%x}" '. + [{id: $id, title: $title, content: $content}]' | store
    echo "$id"
    ;;
  edit)
    title=$(value title)
    text=$(value content; printf x)
    if [ -z "$title${text%x}" ]; then
      form "Edit snippet" "$(load | jq -c --arg id "$2" '.[] | select(.id == $id)')"
      exit 0
    fi
    load | jq -c --arg id "$2" --arg title "$title" --arg content "${text%x}" 'map(if .id == $id then .title = $title | .content = $content else . end)' | store
    echo "$2"
    ;;
  delete)
    load | jq -c --arg id "$2" 'map(select(.id != $id))' | store
    ;;
  paste)
    text=$(content "$2" && printf x) || exit 1
    previous=$(pbpaste; printf x)
    printf '%s' "${text%x}" | openspot clipboard copy
    openspot clipboard paste || exit 1
    sleep 0.3
    if [ "$previous" != x ]; then
      printf '%s' "${previous%x}" | openspot clipboard copy
    fi
    ;;
  open)
    text=$(content "$2" && printf x) || exit 1
    printf '%s' "${text%x}" | openspot clipboard copy
    echo "toast=Copied"
    ;;
esac
