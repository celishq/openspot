#!/bin/sh
# symbol=square.grid.2x2
# subtitle=Open app
# shortcut=a
# read=panel
# global=true
data=${OPENSPOT_DATA:-${TMPDIR:-/tmp}}
pending="$data/uninstall"
kept="$data/uninstall-kept"
lib="$HOME/Library"

# Prints the bundle of each running app, one a line.
running() {
  ps -axo comm= | awk '{ p = index($0, ".app/"); if (p) print substr($0, 1, p + 3) }' | sort -u
}

# Writes text as a value. A path holds no new line, so only a backslash needs care.
esc() {
  printf '%s' "$1" | sed 's/\\/\\\\/g'
}

bundle_id() {
  /usr/bin/defaults read "$1/Contents/Info" CFBundleIdentifier 2>/dev/null
}

# Prints each file that an app leaves in the Library: by its bundle id, and by its exact name.
leftovers() {
  name=$(basename "$1" .app)
  id=$(bundle_id "$1")
  for path in "$lib/Application Support/$name" "$lib/Caches/$name" "$lib/Logs/$name"; do
    [ -e "$path" ] && printf '%s\n' "$path"
  done
  [ -n "$id" ] || return 0
  for path in "$lib/Application Support/$id" "$lib/Caches/$id" "$lib/Preferences/$id.plist" "$lib/Containers/$id" \
    "$lib/Saved Application State/$id.savedState" "$lib/HTTPStorages/$id" "$lib/HTTPStorages/$id.binarycookies" \
    "$lib/WebKit/$id" "$lib/Logs/$id" "$lib/Cookies/$id.binarycookies" \
    "$lib/Group Containers/"*".$id" "$lib/Preferences/ByHost/$id."*.plist "$lib/LaunchAgents/$id"*.plist; do
    [ -e "$path" ] && printf '%s\n' "$path"
  done
}

# Asks an app to quit, as its own Quit does, so that it can save its work.
quit_app() {
  id=$(bundle_id "$1")
  if [ -n "$id" ]; then
    osascript -e "tell application id \"$id\" to quit" >/dev/null 2>&1 && return 0
  fi
  osascript -e "tell application \"$1\" to quit" >/dev/null 2>&1
}

apps() {
  printf 'button=reveal\ntitle=Show in Finder\nshortcut=cmd+return\nclose=true\n\n'
  printf 'button=quit\ntitle=Quit\nshortcut=cmd+shift+q\n\n'
  printf 'button=uninstall\ntitle=Delete\nshortcut=cmd+backspace\n\n'
  printf 'template=row\ngrid=pic name name name name quit\npicture=pic\ntext=name\nbutton=quit\nquit.symbol=xmark.circle\nquit.title=Quit\n\n'
  live="$data/running"
  { echo; running; } > "$live"
  {
    find /Applications /System/Applications "$HOME/Applications" -maxdepth 3 -name '*.app' -prune 2>/dev/null
    echo /System/Library/CoreServices/Finder.app
  } | sed 's/\\/\\\\/g' \
    | awk -F/ '{ name = $NF; sub(/\.app$/, "", name); print name "\t" $0 }' \
    | sort -f -u \
    | awk -F'\t' 'NR == FNR { live[$0] = 1; next }
      {
        printf "row=%s\ntitle=%s\nfile=%s\nname=%s\n", $2, $1, $2, $1
        if ($2 in live) print "tone=on"; else print "hides=quit"
        if ($2 ~ /^\/System\//) print "hides=uninstall"
        print ""
      }' "$live" -
}

# Prints the sheet that asks which files of an app go to the Trash.
uninstall_sheet() {
  app=$1
  name=$(basename "$app" .app)
  files=$( { printf '%s\n' "$app"; leftovers "$app"; } )
  count=$(printf '%s\n' "$files" | wc -l | tr -d ' ')
  lines=$count
  [ "$lines" -gt 7 ] && lines=7
  printf 'title=Delete %s\ndetail=Move the app and its files to the Trash\n' "$name"
  i=0
  while [ "$i" -lt "$lines" ]; do printf 'grid=files files files files\n'; i=$((i + 1)); done
  printf 'grid=cancel cancel remove remove\n\n'
  printf 'repeat=files\n\n'
  printf 'template=row\ngrid=pic name name name name trash\npicture=pic\ntext=name\nswitch=trash\n\n'
  printf 'button=cancel\ntitle=Cancel\n\n'
  printf 'button=remove\ntitle=Move to Trash\nlook=strong\nshortcut=cmd+return\n\n'
  printf '%s\n' "$files" | while IFS= read -r path; do
    keep=true
    grep -Fxq "$path" "$kept" 2>/dev/null && keep=false
    where=$(dirname "$path" | sed "s#^$HOME#~#")
    printf 'row=%s\ntitle=%s\nfile=%s\nname=%s\nname.detail=%s\ntrash=%s\n\n' \
      "$(esc "$path")" "$(esc "$(basename "$path")")" "$(esc "$path")" "$(esc "$(basename "$path")")" "$(esc "$where")" "$keep"
  done
}

# Moves each file to the Trash with Finder, which asks for the admin password when a file needs it, and keeps Put Back.
trash_files() {
  osascript -e 'on run paths' -e 'set targets to {}' -e 'repeat with p in paths' \
    -e 'set end of targets to ((POSIX file (p as text)) as alias)' -e 'end repeat' \
    -e 'tell application "Finder" to delete targets' -e 'end run' "$@" >/dev/null
}

case "$1" in
  read)
    if [ "$OPENSPOT_REASON" = change ] && [ -s "$pending" ] && [ -d "$(cat "$pending")" ]; then
      uninstall_sheet "$(cat "$pending")"
    else
      rm -f "$pending" "$kept"
      apps
    fi
    ;;
  reveal)
    open -R "$2"
    ;;
  open)
    if [ -s "$pending" ]; then open -R "$2"; else open "$2"; fi
    ;;
  quit)
    if ! quit_app "$2"; then
      echo "Openspot cannot quit $(basename "$2" .app). Allow Openspot to control it in Privacy & Security, then try again." >&2
      echo "open=x-apple.systempreferences:com.apple.preference.security?Privacy_Automation"
      exit 1
    fi
    ;;
  uninstall)
    case "$2" in
      /System/*) echo "$(basename "$2" .app) is part of macOS, so it cannot be deleted." >&2; exit 1 ;;
    esac
    printf '%s' "$2" > "$pending.tmp" && mv "$pending.tmp" "$pending"
    rm -f "$kept"
    ;;
  trash)
    [ -s "$pending" ] || exit 0
    grep -Fxv "$2" "$kept" > "$kept.tmp" 2>/dev/null
    [ "$3" = false ] && printf '%s\n' "$2" >> "$kept.tmp"
    mv "$kept.tmp" "$kept"
    ;;
  cancel)
    rm -f "$pending" "$kept"
    ;;
  remove)
    [ -s "$pending" ] || exit 0
    app=$(cat "$pending")
    name=$(basename "$app" .app)
    if running | grep -Fxq "$app"; then
      quit_app "$app"
      i=0
      while running | grep -Fxq "$app" && [ "$i" -lt 50 ]; do sleep 0.1; i=$((i + 1)); done
      if running | grep -Fxq "$app"; then
        echo "$name is still open, so Openspot did not delete it. Quit $name, then try again." >&2
        exit 1
      fi
    fi
    set --
    while IFS= read -r path; do
      grep -Fxq "$path" "$kept" 2>/dev/null || set -- "$@" "$path"
    done <<EOF
$( { printf '%s\n' "$app"; leftovers "$app"; } )
EOF
    if ! trash_files "$@"; then
      echo "Openspot cannot move $name to the Trash. Allow Openspot to control Finder in Privacy & Security, then try again." >&2
      exit 1
    fi
    rm -f "$pending" "$kept"
    case $# in
      1) printf 'toast=Moved %s to the Trash\n' "$name" ;;
      2) printf 'toast=Moved %s and 1 of its files to the Trash\n' "$name" ;;
      *) printf 'toast=Moved %s and %s of its files to the Trash\n' "$name" "$(($# - 1))" ;;
    esac
    ;;
esac
