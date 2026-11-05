#!/bin/sh
export LC_ALL=en_US.UTF-8
data="${OPENSPOT_CONFIG:-$HOME/.config/openspot}/data/snippets.json"

load() {
  if [ -s "$data" ]; then cat "$data"; else echo '[]'; fi
}

store() {
  mkdir -p "$(dirname "$data")"
  cat > "$data.$$" && mv "$data.$$" "$data"
}

content() {
  load | jq -e -j --arg id "$1" '.[] | select(.id == $id) | .content' || {
    echo "This snippet is gone." >&2
    exit 1
  }
}

case "$1" in
  items)
    load | jq -c '.[] | {title, subtitle: (.content | gsub("\\s+"; " ") | .[0:200]), run: .id}'
    ;;
  form)
    if [ "$2" = edit ]; then
      title="Edit snippet"
      values=$(load | jq -c --arg id "$3" '.[] | select(.id == $id)')
    else
      title="New snippet"
      values='{"title":"","content":""}'
    fi
    jq -nc --arg title "$title" --argjson v "$values" '{title: $title, fields: [
      {name: "title", label: "Name", type: "text", value: $v.title, required: true},
      {name: "content", label: "Text", type: "multiline", value: $v.content, required: true}
    ]}'
    ;;
  new)
    id=$(uuidgen)
    values=$(cat)
    load | jq -c --arg id "$id" --argjson v "$values" '. + [{id: $id, title: $v.title, content: $v.content}]' | store
    echo "$id"
    ;;
  edit)
    values=$(cat)
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
  *)
    text=$(content "$1" && printf x) || exit 1
    printf '%s' "${text%x}" | pbcopy
    ;;
esac
