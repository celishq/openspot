#!/bin/sh
data="$OPENSPOT_DATA/links.json"
icons="$OPENSPOT_DATA/icons"
. "$OPENSPOT_SH"
agent="Mozilla/5.0 (Macintosh) Openspot"

# Makes a jq value safe for one line of a text block.
esc='def esc: gsub("\\\\"; "\\\\") | gsub("\n"; "\\n");'

# Makes the list once, with the folder shortcuts.
prepare() {
  [ -e "$data" ] && return
  shots=$(defaults read com.apple.screencapture location 2>/dev/null || echo "~/Desktop")
  jq -nc --arg shots "$shots" '[
    {id: "downloads", title: "Downloads", url: "~/Downloads"},
    {id: "screenshots", title: "Screenshots", url: $shots}
  ]' | store
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
        echo "Openspot cannot find $1." >&2
        exit 1
      fi
      ;;
  esac
}

# Prints the form values as one JSON object, with a full link. A path stays as it is.
checked() {
  jq -nc --arg title "$(value input.title)" --arg url "$(value input.url)" '{$title, $url} | .url |= (gsub("^\\s+|\\s+$"; "") | if test("^[/~]") or test("^[a-zA-Z][a-zA-Z0-9+.-]*:") then . else "https://" + . end)
    | if (.url | test("^[/~]") | not) and (.url | test("\\s")) then error("bad") else . end' 2>/dev/null || {
    echo "Enter a link with no spaces, or a path." >&2
    exit 1
  }
}

# A stop of the call that fetches ends this process: the half-fetched image goes with it.
trap 'rm -f "$icons"/.*."$$"; exit 143' TERM INT

# Saves one image from the address to a host's icon file. Fails when the address gives no image Openspot can read.
save_icon() {
  file="$icons/.$2.$$"
  png="$icons/.$2.png.$$"
  kind=$(curl -fsSL -m 5 -A "$agent" -o "$file" -w '%{content_type}' "$1" 2>/dev/null) || kind=""
  case "$kind" in
    image/*)
      if sips -s format png "$file" --out "$png" >/dev/null 2>&1 && mv "$png" "$icons/$2.png"; then
        rm -f "$file"
        return 0
      fi
      rm -f "$png"
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

# Looks for the icon of the saved link's site when it has none, inside the call that saved the link, so that Openspot
# ends the fetch with the call. A site with no icon is tried again at a save of a link to it a week or more after the
# last try.
fetch_missing() {
  printf '%s' "$1" | jq -r '.url | capture("^(?<origin>https?://(?<host>[^/?#]+))") | "\(.origin) \(.host)"' |
    while read -r origin host; do
      [ -d "$icons" ] && find "$icons" -name "$host.none" -mtime +7 -delete
      if [ ! -e "$icons/$host.png" ] && [ ! -e "$icons/$host.none" ]; then
        fetch_icon "$origin" "$host"
      fi
    done
}

# Prints the form with this title and these values.
form() {
  jq -nr --arg title "$1" --argjson v "$2" "$esc"'"title=\($title)

field=title
title=Name
value=\($v.title | esc)
required=true

field=url
title=Link
value=\($v.url | esc)
required=true
placeholder=example.com or ~/Downloads"'
}

prepare

case "$1" in
  show)
    printf 'button=copy\ntitle=Copy\nshortcut=cmd+return\nclose=true\n\n'
    printf 'button=reveal\ntitle=Show in Finder\nshortcut=cmd+r\nclose=true\n\n'
    printf 'button=edit\ntitle=Edit\nshortcut=cmd+e\nform=true\n\n'
    printf 'button=delete\ntitle=Delete\nshortcut=cmd+backspace\nconfirm=Press again to delete\n\n'
    printf 'button=new\ntitle=New link\nshortcut=cmd+n\nscope=spot\nform=true\nplaceholder=Link to add\n\n'
    [ -s "$data" ] || exit 0
    set --
    for icon in "$icons"/*.png; do [ -e "$icon" ] && set -- "$@" "${icon##*/}"; done
    jq -r --arg icons "$icons" --arg home "$HOME" "$esc"'$ARGS.positional as $found | .[]
      | if (.url | test("^[/~]")) then
          "row=\(.id | esc)\ntitle=\(.title | esc)\ndetail=\(.url | esc)\nicon=\(.url | if startswith("~") then $home + .[1:] else . end | esc)\n"
        else
          (.url | sub("^[a-zA-Z][a-zA-Z0-9+.-]*:(//)?"; "") | sub("[/?#].*$"; "")) as $host
          | "row=\(.id | esc)\ntitle=\(.title | esc)\ndetail=\($host | esc)\nhides=reveal\n"
          + (if ($found | index($host + ".png")) then "icon=\("\($icons)/\($host).png" | esc)\n" else "icon=link\n" end)
        end' "$data" --args "$@"
    ;;
  new)
    if [ -z "$(value input.title)$(value input.url)" ]; then
      form "New link" "$(jq -nc --arg url "$(value search)" '{title: "", url: $url}')"
      exit 0
    fi
    id=$(uuidgen)
    values=$(checked) || exit 1
    load | jq -c --arg id "$id" --argjson v "$values" '. + [{id: $id, title: $v.title, url: $v.url}]' | store
    fetch_missing "$values" >/dev/null 2>&1 </dev/null
    openspot select "$id"
    ;;
  edit)
    if [ -z "$(value input.title)$(value input.url)" ]; then
      form "Edit link" "$(load | jq -c --arg id "$2" '.[] | select(.id == $id)')"
      exit 0
    fi
    values=$(checked) || exit 1
    load | jq -c --arg id "$2" --argjson v "$values" 'map(if .id == $id then .title = $v.title | .url = $v.url else . end)' | store
    fetch_missing "$values" >/dev/null 2>&1 </dev/null
    openspot select "$2"
    ;;
  delete)
    load | jq -c --arg id "$2" 'map(select(.id != $id))' | store
    ;;
  copy)
    url=$(link "$2") || exit 1
    printf '%s' "$url" | openspot clipboard copy
    openspot toast Copied
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
