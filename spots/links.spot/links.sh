#!/bin/sh

# A delete waits for the delete before it, so two quick deletes never write over each other. A save keeps no lock, since
# a stop of its icon fetch must reach this process.
[ "$1" != delete ] || [ -n "${LINKS_LOCKED-}" ] || LINKS_LOCKED=1 exec lockf -k "$OPENSPOT_DATA/links.lock" "$0" "$@"

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
trap 'rm -f "$icons"/.*."$$" "$icons"/.*."$$".svg; exit 143' TERM INT

# Saves one image from the address to a host's icon file, a vector image at 256 pixels. Fails when the address gives
# no image Openspot can read.
save_icon() {
  file="$icons/.$2.$$"
  png="$icons/.$2.png.$$"
  kind=$(curl -fsSL -m 5 -A "$agent" -o "$file" -w '%{content_type}' "$1" 2>/dev/null) || kind=""
  size=
  case "$kind" in image/svg*) mv "$file" "$file.svg" && file="$file.svg" size=256 ;; esac
  case "$kind" in
    image/*)
      if sips -s format png ${size:+-Z "$size"} "$file" --out "$png" >/dev/null 2>&1 && mv "$png" "$icons/$2.png"; then
        rm -f "$file"
        return 0
      fi
      rm -f "$png"
      ;;
  esac
  rm -f "$file"
  return 1
}

# Finds a site's icon on its page, a vector icon first, then the largest kind, or else at the usual address.
fetch_icon() {
  origin=$1
  host=$2
  mkdir -p "$icons"
  tags=$(curl -fsSL -m 5 -A "$agent" "$origin/" 2>/dev/null | tr '>' '\n' | grep -i '<link')
  hrefs=$(
    for kind in 'svg' 'apple-touch-icon' '(shortcut )?icon'; do
      rel=$kind type=.
      [ "$kind" = svg ] && rel='(shortcut )?icon' type=svg
      printf '%s\n' "$tags" \
        | grep -iE "rel=[\"']?$rel[\"' ]" \
        | grep -i "$type" \
        | grep -i 'href=' \
        | sed -E "s/.*[[:space:]][hH][rR][eE][fF]=[\"']?([^\"' ]+).*/\\1/; s/&amp;/\\&/g"
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
  jq -nr --arg title "$1" --argjson v "$2" "$esc"'"frame=\ntype=form\ntitle=\($title)

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

item=$(value item)

case "$1" in
  show)
    printf 'button=copy\ntitle=Copy\nshortcut=cmd+return\n\n'
    printf 'button=reveal\ntitle=Show in Finder\nshortcut=cmd+r\n\n'
    printf 'button=edit\ntitle=Edit\nshortcut=cmd+e\nclose=false\n\n'
    printf 'button=delete\ntitle=Delete\nshortcut=cmd+backspace\nconfirm=Press again to delete\nclose=false\n\n'
    printf 'button=new\ntitle=New link\nshortcut=cmd+n\nscope=spot\nclose=false\nplaceholder=Link to add\n\n'
    [ -s "$data" ] || exit 0
    set --
    for icon in "$icons"/*.png; do [ -e "$icon" ] && set -- "$@" "${icon##*/}"; done
    jq -r --arg icons "$icons" --arg home "$HOME" "$esc"'$ARGS.positional as $found | .[]
      | if (.url | test("^[/~]")) then
          "item=\(.id | esc)\ntitle=\(.title | esc)\ndetail=\(.url | esc)\nicon=\(.url | if startswith("~") then $home + .[1:] else . end | esc)\n"
        else
          (.url | sub("^[a-zA-Z][a-zA-Z0-9+.-]*:(//)?"; "") | sub("[/?#].*$"; "")) as $host
          | "item=\(.id | esc)\ntitle=\(.title | esc)\ndetail=\($host | esc)\nhides=reveal\n"
          + (if ($found | index($host + ".png")) then "icon=\("\($icons)/\($host).png" | esc)\n" else "icon=link\n" end)
        end' "$data" --args "$@"
    ;;
  add)
    # Keeps the link that was handed to it, named by its title, or by the link when it has none.
    values=$(checked) || exit 1
    values=$(printf '%s' "$values" | jq -c 'if .title == "" then .title = .url else . end')
    id=$(uuidgen)
    load | jq -c --arg id "$id" --argjson v "$values" '. + [{id: $id, title: $v.title, url: $v.url}]' | store
    fetch_missing "$values" >/dev/null 2>&1 </dev/null
    openspot select "$id"
    ;;
  new)
    # Asks with its own form, filled with what the call gave, until both the name and the link are given.
    if [ -z "$(value input.title)" ] || [ -z "$(value input.url)" ]; then
      form "New link" "$(jq -nc --arg title "$(value input.title)" --arg url "$(value input.url)" '{$title, $url}')"
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
      form "Edit link" "$(load | jq -c --arg id "$item" '.[] | select(.id == $id)')"
      exit 0
    fi
    values=$(checked) || exit 1
    load | jq -c --arg id "$item" --argjson v "$values" 'map(if .id == $id then .title = $v.title | .url = $v.url else . end)' | store
    fetch_missing "$values" >/dev/null 2>&1 </dev/null
    openspot select "$item"
    ;;
  delete)
    load | jq -c --arg id "$item" 'map(select(.id != $id))' | store
    ;;
  copy)
    url=$(link "$item") || exit 1
    printf '%s' "$url" | openspot clipboard copy
    openspot toast Copied
    ;;
  reveal)
    url=$(link "$item") || exit 1
    check_path "$url"
    open -R "$url"
    ;;
  press)
    url=$(link "$item") || exit 1
    check_path "$url"
    open "$url"
    ;;
esac
