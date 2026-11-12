#!/bin/sh
# title=Draw
# icon=scribble.variable
# detail=Sketch on a board
# size=small
# read=sheet
. "$OPENSPOT_SH"

dir=$(cd "$(dirname "$0")" && pwd)/draw
data=${OPENSPOT_DATA:?}
boards="$data/boards"
bin="$data/Draw"
mkdir -p "$boards"

fail() {
  printf '%s\n' "$1" >&2
  exit 1
}

title_of() {
  /usr/bin/jq -r '.title // "Untitled board"' "$1" 2>/dev/null || printf 'Untitled board'
}

# Says when a board last changed, such as `Edited 5 min ago`.
edited() {
  age=$(( $(date +%s) - $(stat -f %m "$1") ))
  if [ "$age" -lt 60 ]; then printf 'Edited just now'
  elif [ "$age" -lt 3600 ]; then printf 'Edited %d min ago' $((age / 60))
  elif [ "$age" -lt 86400 ]; then printf 'Edited %d h ago' $((age / 3600))
  else printf 'Edited %s' "$(date -r "$(stat -f %m "$1")" '+%b %-d')"
  fi
}

# Builds the board app once, and again after its source changes.
build() {
  newest=$(ls -t "$dir"/model/*.swift "$dir"/app/*.swift | head -n 1)
  [ -x "$bin" ] && [ "$bin" -nt "$newest" ] && return 0
  printf 'title=Building Draw\ndetail=A few seconds, once\n---\n'
  /usr/bin/xcrun swiftc -O -o "$bin.new" "$dir"/model/*.swift "$dir"/app/*.swift 2> "$data/build.log" && mv "$bin.new" "$bin"
}

launch() {
  build || fail "Openspot cannot build Draw: $(grep -m 1 error: "$data/build.log"). Install the Command Line Tools with \`xcode-select --install\`."
  nohup "$bin" "$1" > /dev/null 2>&1 &
}

new_board() {
  id=$(uuidgen | tr '[:upper:]' '[:lower:]')
  file="$boards/$id.json"
  printf '{"figures":[],"title":"Untitled board"}' > "$file"
  launch "$file"
}

board() {
  file="$boards/$1.json"
  [ -f "$file" ] || fail "This board is gone."
}

case "$1" in
  read)
    printf 'recents=false\n\n'
    printf 'button=open\ntitle=Open\nclose=true\n\n'
    printf 'button=new\ntitle=New board\nshortcut=cmd+n\nscope=command\nclose=true\n\n'
    printf 'button=rename\ntitle=Rename\nshortcut=cmd+r\nform=true\n\n'
    printf 'button=delete\ntitle=Delete\nshortcut=cmd+backspace\nconfirm=Press again to move it to the Trash\n\n'
    printf 'button=reveal\ntitle=Show boards in Finder\nshortcut=cmd+o\nscope=command\n\n'
    printf 'row=new\ntitle=New board\ndetail=A blank board\nicon=plus.square.dashed\nhides=rename\nhides=delete\n\n'
    ls -t "$boards" | while IFS= read -r name; do
      case "$name" in *.json) ;; *) continue ;; esac
      id=${name%.json}
      file="$boards/$name"
      icon=scribble.variable
      [ -f "$boards/$id.png" ] && icon="$boards/$id.png"
      printf 'row=%s\ntitle=%s\ndetail=%s\nicon=%s\n\n' "$id" "$(esc "$(title_of "$file")")" "$(edited "$file")" "$(esc "$icon")"
    done
    ;;
  open)
    if [ "${2:-new}" = new ]; then
      new_board
    else
      board "$2"
      launch "$file"
    fi
    ;;
  new)
    new_board
    ;;
  rename)
    board "$2"
    name=$(value name)
    if [ -z "$name" ]; then
      printf 'title=Rename board\n\nfield=name\ntitle=Name\nvalue=%s\nrequired=true\n' "$(esc "$(title_of "$file")")"
      exit 0
    fi
    /usr/bin/jq -c --arg title "$(printf %s "$name" | tr '\n' ' ')" '.title = $title' "$file" > "$file.$$" && mv "$file.$$" "$file" || fail "Openspot cannot rename it, so it keeps its name."
    printf '%s\n' "$2"
    ;;
  delete)
    board "$2"
    title=$(title_of "$file")
    trash="$HOME/.Trash/$(printf %s "$title" | tr '/:' '--')-$(date +%s)"
    [ -d "$boards/$2.assets" ] && mv "$boards/$2.assets" "$trash.assets"
    mv "$file" "$trash.json" || fail "Openspot cannot move $title to the Trash, so it stays."
    [ -f "$boards/$2.png" ] && mv "$boards/$2.png" "$trash.png"
    rm -f "$file.lock"
    printf 'toast=%s\n' "$(esc "Moved $title to the Trash.")"
    ;;
  reveal)
    open "$boards"
    ;;
esac
