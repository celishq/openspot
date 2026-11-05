#!/bin/sh
export LC_ALL=en_US.UTF-8
data="$HOME/.config/openspot/data/quicklinks.json"

load() {
  if [ -s "$data" ]; then cat "$data"; else echo '[]'; fi
}

store() {
  mkdir -p "$(dirname "$data")"
  cat > "$data.$$" && mv "$data.$$" "$data"
}

link() {
  load | jq -e -j --arg id "$1" '.[] | select(.id == $id) | .url' || {
    echo "This quicklink is gone." >&2
    exit 1
  }
}

# Reads the form values, and prints them with a full link.
checked() {
  jq -c '.url |= (gsub("^\\s+|\\s+$"; "") | if test("^[a-zA-Z][a-zA-Z0-9+.-]*:") then . else "https://" + . end)
    | if (.url | test("\\s")) then error("bad") else . end' 2>/dev/null || {
    echo "Enter a link with no spaces." >&2
    exit 1
  }
}

case "$1" in
  items)
    load | jq -c '.[] | {title, subtitle: (.url | sub("^[a-zA-Z][a-zA-Z0-9+.-]*:(//)?"; "") | sub("/.*$"; "")), run: .id}'
    ;;
  form)
    if [ "$2" = edit ]; then
      title="Edit quicklink"
      values=$(load | jq -c --arg id "$3" '.[] | select(.id == $id)')
    else
      title="New quicklink"
      values='{"title":"","url":""}'
    fi
    jq -nc --arg title "$title" --argjson v "$values" '{title: $title, fields: [
      {name: "title", label: "Name", type: "text", value: $v.title, required: true},
      {name: "url", label: "Link", type: "text", value: $v.url, required: true, placeholder: "example.com"}
    ]}'
    ;;
  new)
    id=$(uuidgen)
    values=$(checked) || exit 1
    load | jq -c --arg id "$id" --argjson v "$values" '. + [{id: $id, title: $v.title, url: $v.url}]' | store
    echo "$id"
    ;;
  edit)
    values=$(checked) || exit 1
    load | jq -c --arg id "$2" --argjson v "$values" 'map(if .id == $id then .title = $v.title | .url = $v.url else . end)' | store
    echo "$2"
    ;;
  delete)
    load | jq -c --arg id "$2" 'map(select(.id != $id))' | store
    ;;
  copy)
    link "$2" | pbcopy
    ;;
  *)
    url=$(link "$1") || exit 1
    open "$url"
    ;;
esac
