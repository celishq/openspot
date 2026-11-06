#!/bin/sh
# symbol=link
# subtitle=Open a link
# key=l
# read=panel
# rank=1
export LC_ALL=en_US.UTF-8
data="$OPENSPOT_DATA/links.json"
icons="$OPENSPOT_DATA/icons"
agent="Mozilla/5.0 (Macintosh) Openspot"

# Makes a jq value safe for one line of a text block.
esc='def esc: gsub("\\\\"; "\\\\") | gsub("\n"; "\\n");'

# Makes the list once: saved quicklinks move over, and the folder shortcuts join them.
prepare() {
  [ -e "$data" ] && return
  old="$OPENSPOT_DATA/quicklinks.json"
  if [ -s "$old" ]; then saved=$(cat "$old"); else saved='[]'; fi
  shots=$(defaults read com.apple.screencapture location 2>/dev/null || echo "~/Desktop")
  printf '%s' "$saved" | jq -c --arg shots "$shots" '. + [
    {id: "downloads", title: "Downloads", url: "~/Downloads"},
    {id: "screenshots", title: "Screenshots", url: $shots}
  ]' | store
  rm -f "$old"
}

load() {
  if [ -s "$data" ]; then cat "$data"; else echo '[]'; fi
}

store() {
  cat > "$data.$$" && mv "$data.$$" "$data"
}

# Prints where a link goes, with the home folder written out.
link() {
  load | jq -e -j --arg id "$1" --arg home "$HOME" '.[] | select(.id == $id) | .url
    | if startswith("~") then $home + .[1:] else . end' || {
    echo "This link is gone." >&2
    exit 1
  }
}

# Stops with a message when a path no longer leads anywhere.
check_path() {
  case "$1" in
    /*)
      if [ ! -e "$1" ]; then
        echo "Cannot find $1." >&2
        exit 1
      fi
      ;;
  esac
}

# Reads the form values on stdin, and prints them as one JSON object.
form_values() {
  jq -Rsc 'split("\n") | map(capture("^(?<key>[^=]+)=(?<value>.*)$")? | .value |= gsub("\\\\(?<c>[n\\\\])"; if .c == "n" then "\n" else .c end)) | from_entries'
}

# Reads the form values, and prints them with a full link. A path stays as it is.
checked() {
  form_values | jq -c '.url |= (gsub("^\\s+|\\s+$"; "") | if test("^[/~]") or test("^[a-zA-Z][a-zA-Z0-9+.-]*:") then . else "https://" + . end)
    | if (.url | test("^[/~]") | not) and (.url | test("\\s")) then error("bad") else . end' 2>/dev/null || {
    echo "Enter a link with no spaces, or a path." >&2
    exit 1
  }
}

# Saves one image from the address to a host's icon file. Fails when the address gives no image Openspot can read.
save_icon() {
  file="$icons/.$2.$$"
  kind=$(curl -fsSL -m 5 -A "$agent" -o "$file" -w '%{content_type}' "$1" 2>/dev/null) || kind=""
  case "$kind" in
    image/*)
      if sips -g pixelWidth "$file" >/dev/null 2>&1; then
        mv "$file" "$icons/$2.icon"
        return 0
      fi
      ;;
  esac
  rm -f "$file"
  return 1
}

# Finds a site's icon on its page, largest kind first, or else at the usual address.
fetch_icon() {
  origin=$1
  host=$2
  mkdir -p "$icons"
  tags=$(curl -fsSL -m 5 -A "$agent" "$origin/" 2>/dev/null | tr '>' '\n' | grep -i '<link')
  hrefs=$(
    for kind in 'apple-touch-icon' '(shortcut )?icon'; do
      printf '%s\n' "$tags" \
        | grep -iE "rel=[\"']?$kind[\"' ]" \
        | grep -i 'href=' \
        | sed -E "s/.*[hH][rR][eE][fF]=[\"']?([^\"' ]+).*/\\1/; s/&amp;/\\&/g"
    done
  )
  for href in $hrefs "$origin/favicon.ico"; do
    case "$href" in
      data:*) continue ;;
      http://*|https://*) address=$href ;;
      //*) address="https:$href" ;;
      /*) address="$origin$href" ;;
      *) address="$origin/$href" ;;
    esac
    save_icon "$address" "$host" && return 0
  done
  touch "$icons/$host.none"
}

# Looks for the icon of each web link that has none. A site with no icon is tried again after a week.
fetch_missing() {
  [ -d "$icons" ] && find "$icons" -name '*.none' -mtime +7 -delete
  load | jq -r '.[].url | capture("^(?<origin>https?://(?<host>[^/?#]+))") | "\(.origin) \(.host)"' | sort -u |
    while read -r origin host; do
      if [ ! -e "$icons/$host.icon" ] && [ ! -e "$icons/$host.none" ]; then
        fetch_icon "$origin" "$host"
      fi
    done
}

# Prints the form with this title and these values.
form() {
  jq -nr --arg title "$1" --argjson v "$2" "$esc"'"title=\($title)

field=title
label=Name
value=\($v.title | esc)
required=true

field=url
label=Link
value=\($v.url | esc)
required=true
placeholder=example.com or ~/Downloads"'
}

prepare

case "$1" in
  read)
    printf 'action=copy\ntitle=Copy\nkey=cmd+return\nclose=true\n\n'
    printf 'action=reveal\ntitle=Show in Finder\nkey=cmd+r\nclose=true\n\n'
    printf 'action=edit\ntitle=Edit\nkey=cmd+e\nform=true\n\n'
    printf 'action=delete\ntitle=Delete\nkey=cmd+backspace\nconfirm=Press again to delete\n\n'
    printf 'action=new\ntitle=New link\nkey=cmd+n\nscope=command\nform=true\n\n'
    found=$(ls "$icons" 2>/dev/null | jq -R . | jq -sc .)
    load | jq -r --arg icons "$icons" --argjson found "$found" --arg home "$HOME" "$esc"'.[]
      | if (.url | test("^[/~]")) then
          "row=\(.title | esc)\ndetail=\(.url | esc)\nrun=\(.id | esc)\nfile=\(.url | if startswith("~") then $home + .[1:] else . end | esc)\n"
        else
          (.url | sub("^[a-zA-Z][a-zA-Z0-9+.-]*:(//)?"; "") | sub("[/?#].*$"; "")) as $host
          | "row=\(.title | esc)\ndetail=\($host | esc)\nrun=\(.id | esc)\nsymbol=link\nhides=reveal\n"
          + (if ($found | index($host + ".icon")) then "image=\("\($icons)/\($host).icon" | esc)\n" else "" end)
        end'
    fetch_missing >/dev/null 2>&1 </dev/null &
    ;;
  new)
    input=$(cat)
    if [ -z "$input" ]; then
      form "New link" '{"title":"","url":""}'
      exit 0
    fi
    id=$(uuidgen)
    values=$(printf '%s\n' "$input" | checked) || exit 1
    load | jq -c --arg id "$id" --argjson v "$values" '. + [{id: $id, title: $v.title, url: $v.url}]' | store
    fetch_missing >/dev/null 2>&1 </dev/null &
    echo "$id"
    ;;
  edit)
    input=$(cat)
    if [ -z "$input" ]; then
      form "Edit link" "$(load | jq -c --arg id "$2" '.[] | select(.id == $id)')"
      exit 0
    fi
    values=$(printf '%s\n' "$input" | checked) || exit 1
    load | jq -c --arg id "$2" --argjson v "$values" 'map(if .id == $id then .title = $v.title | .url = $v.url else . end)' | store
    echo "$2"
    ;;
  delete)
    load | jq -c --arg id "$2" 'map(select(.id != $id))' | store
    ;;
  copy)
    link "$2" | pbcopy
    ;;
  reveal)
    url=$(link "$2") || exit 1
    check_path "$url"
    open -R "$url"
    ;;
  open)
    url=$(link "$2") || exit 1
    check_path "$url"
    open "$url"
    ;;
esac
