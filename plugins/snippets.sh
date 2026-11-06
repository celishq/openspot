#!/bin/sh
# symbol=text.quote
# subtitle=Copy text
# key=n
# read=panel
# rank=3
export LC_ALL=en_US.UTF-8
data="$OPENSPOT_DATA/snippets.json"

# Makes a jq value safe for one line of a text block.
esc='def esc: gsub("\\\\"; "\\\\") | gsub("\n"; "\\n");'

# Reads the form values on stdin, and prints them as one JSON object.
form_values() {
  jq -Rsc 'split("\n") | map(capture("^(?<key>[^=]+)=(?<value>.*)$")? | .value |= gsub("\\\\(?<c>[n\\\\])"; if .c == "n" then "\n" else .c end)) | from_entries'
}

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
label=Name
value=\($v.title | esc)
required=true

field=content
label=Text
type=multiline
value=\($v.content | esc)
required=true"'
}

case "$1" in
  read)
    printf 'action=open\ntitle=Copy\n\n'
    printf 'action=paste\ntitle=Paste\nkey=cmd+return\nclose=true\n\n'
    printf 'action=edit\ntitle=Edit\nkey=cmd+e\nform=true\n\n'
    printf 'action=delete\ntitle=Delete\nkey=cmd+backspace\nconfirm=Press again to delete\n\n'
    printf 'action=new\ntitle=New snippet\nkey=cmd+n\nscope=command\nform=true\n\n'
    load | jq -r "$esc"'.[] | "row=\(.title | esc)\ndetail=\(.content | gsub("\\s+"; " ") | .[0:200] | esc)\nrun=\(.id | esc)\n"'
    ;;
  new)
    input=$(cat)
    if [ -z "$input" ]; then
      form "New snippet" '{"title":"","content":""}'
      exit 0
    fi
    id=$(uuidgen)
    values=$(printf '%s\n' "$input" | form_values)
    load | jq -c --arg id "$id" --argjson v "$values" '. + [{id: $id, title: $v.title, content: $v.content}]' | store
    echo "$id"
    ;;
  edit)
    input=$(cat)
    if [ -z "$input" ]; then
      form "Edit snippet" "$(load | jq -c --arg id "$2" '.[] | select(.id == $id)')"
      exit 0
    fi
    values=$(printf '%s\n' "$input" | form_values)
    load | jq -c --arg id "$2" --argjson v "$values" 'map(if .id == $id then .title = $v.title | .content = $v.content else . end)' | store
    echo "$2"
    ;;
  delete)
    load | jq -c --arg id "$2" 'map(select(.id != $id))' | store
    ;;
  paste)
    text=$(content "$2" && printf x) || exit 1
    previous=$(pbpaste; printf x)
    printf '%s' "${text%x}" | pbcopy
    sleep 0.2
    if ! osascript -e 'tell application "System Events" to keystroke "v" using command down' 2>/dev/null; then
      echo "Copied. Press Command-V, or allow Openspot in Accessibility." >&2
      exit 1
    fi
    sleep 0.3
    if [ "$previous" != x ]; then
      printf '%s' "${previous%x}" | pbcopy
    fi
    ;;
  open)
    text=$(content "$2" && printf x) || exit 1
    printf '%s' "${text%x}" | pbcopy
    ;;
esac
