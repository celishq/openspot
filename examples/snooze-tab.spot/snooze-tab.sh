#!/bin/sh
# Snooze closes the front tab of the frontmost browser once the person picks a time on the snooze sheet, and due opens
# it again in that browser. The sheet starts with Snooze Current Tab, pinned, then lists each snoozed tab: Return opens
# it now, Copy Link copies its url, and Remove forgets it. Open All opens every one now. The rows also show in the main search.
# A timer keeps "<browser id> <url> <title>". A tab snoozed for Someday has no time, so it stays in the data folder.
. "$OPENSPOT_SH"

# The browsers whose front tab AppleScript can read, by bundle id: Safari, or a browser built on Chromium.
browser_kind() {
  case "$1" in
    com.apple.Safari|com.apple.SafariTechnologyPreview) printf safari ;;
    com.google.Chrome|com.google.Chrome.canary|company.thebrowser.Browser|com.brave.Browser|com.microsoft.edgemac|com.vivaldi.Vivaldi|com.operasoftware.Opera) printf chromium ;;
  esac
}

# The bundle id and the name of the frontmost app, which stays in front while the panel shows.
front_id() {
  lsappinfo info -only bundleid "$(lsappinfo front)" | sed -n 's/^.*bundleID="\([^"]*\)".*$/\1/p'
}

front_name() {
  lsappinfo info -only name "$(lsappinfo front)" | sed -n '1s/^"\([^"]*\)".*$/\1/p'
}

# Prints the url and the title of the front tab of a browser, a line each, in one AppleScript call.
read_tab() {
  case "$(browser_kind "$1")" in
    safari) tab="current tab" name="name" ;;
    chromium) tab="active tab" name="title" ;;
    *) return ;;
  esac
  osascript -e "tell application id \"$1\" to set front_tab to $tab of front window" \
    -e "tell application id \"$1\" to return (URL of front_tab) & linefeed & ($name of front_tab)" 2>/dev/null
}

close_tab() {
  case "$(browser_kind "$1")" in
    safari) osascript -e "tell application id \"$1\" to close current tab of front window" >/dev/null 2>&1 ;;
    chromium) osascript -e "tell application id \"$1\" to close active tab of front window" >/dev/null 2>&1 ;;
  esac
}

somedays="$OPENSPOT_DATA/someday.tsv"

# Prints each snoozed tab as a line: id, time or someday, browser, url, title, split by tabs. A Someday tab's id starts
# with someday-.
tabs() {
  openspot timer list 2>/dev/null | openspot_rows text at title | while IFS="$(printf '\t')" read -r id at value; do
    rest=${value#* }
    printf '%s\t%s\t%s\t%s\t%s\n' "$id" "$at" "${value%% *}" "${rest%% *}" "${rest#* }"
  done
  [ -f "$somedays" ] && cat "$somedays"
}

# Forgets a snoozed tab: its timer, or its line of Someday.
forget() {
  case "$1" in
    someday-*) grep -v "^$1	" "$somedays" | openspot_keep "$somedays" ;;
    *) openspot timer remove "$1" >/dev/null ;;
  esac
}

# The words of a time, such as Thu 8:00.
when() {
  [ "$1" = someday ] && { printf Someday; return; }
  seconds=$(date -j -u -f "%Y-%m-%dT%H:%M:%SZ" "$1" +%s 2>/dev/null) || { printf '%s' "$1"; return; }
  date -r "$seconds" "+%a %b %-d, %-H:%M"
}

# The icon of a page: its site's favicon, which Openspot fetches once.
icon() {
  case "$1" in
    http://*|https://*) printf '%s/favicon.ico' "$(printf '%s' "$1" | sed -E 's#^(https?://[^/]+).*#\1#')" ;;
    *) printf moon.zzz ;;
  esac
}

# Snoozes the front tab of the frontmost browser until the time the person picks, and closes it. A title read earlier
# for the same browser names the picker; the tab itself is read after the pick, so the timer keeps the tab it closes.
snooze() {
  browser=$(front_id)
  if [ -z "$(browser_kind "$browser")" ]; then
    echo "$(front_name) is not a browser that Snooze Tab can read. Use Safari, Chrome, Arc, Brave, Edge, Vivaldi or Opera." >&2
    exit 1
  fi
  if [ "$1" = "$browser" ] && [ -n "$2" ]; then
    at=$(openspot spot ask openspot/snooze --title "$2") || exit 0
  else
    at=$(openspot spot ask openspot/snooze) || exit 0
  fi
  tab=$(read_tab "$browser")
  url=$(printf '%s\n' "$tab" | sed -n 1p)
  title=$(printf '%s\n' "$tab" | sed -n 2p)
  [ -n "$url" ] || { echo "$(front_name) shows no tab." >&2; exit 1; }
  if [ "$at" = someday ]; then
    { [ -f "$somedays" ] && cat "$somedays"; printf 'someday-%s\tsomeday\t%s\t%s\t%s\n' "$(date +%s)$$" "$browser" "$url" "$title"; } | openspot_keep "$somedays" || exit 1
  else
    openspot timer add "$at" "$browser $url $title" >/dev/null || exit 1
  fi
  close_tab "$browser"
  openspot toast "Snoozed the tab."
}

case "$1" in
  show)
    browser=$(front_id)
    tab=$([ -n "$(browser_kind "$browser")" ] && read_tab "$browser")
    url=$(printf '%s\n' "$tab" | sed -n 1p)
    title=$(printf '%s\n' "$tab" | sed -n 2p)
    printf 'button=remove\ntitle=Remove\nshortcut=cmd+backspace\n\nbutton=copy\ntitle=Copy Link\n'
    openspot_item current "Snooze Current Tab" "${title:-${url:-The front tab of your browser}}" moon.zzz
    printf 'pin=top\nhides=remove\nhides=copy\nclose=false\n'
    openspot_kv browser "$browser"
    [ -z "$title" ] || openspot_kv page "$title"
    tabs | while IFS="$(printf '\t')" read -r id at browser url title; do
      openspot_item "$id" "${title:-$url}" "$(when "$at")" "$(icon "$url")"
    done
    ;;
  open)
    if [ "$2" = current ]; then
      snooze "$(value item.browser)" "$(value item.page)"
      exit
    fi
    tabs | awk -F '\t' -v id="$2" '$1 == id { print $3 "\t" $4 }' | while IFS="$(printf '\t')" read -r browser url; do
      forget "$2" && open -b "$browser" "$url"
    done
    ;;
  remove)
    [ -n "$2" ] && [ "$2" != current ] && forget "$2"
    ;;
  copy)
    url=$(tabs | awk -F '\t' -v id="$2" '$1 == id { print $4 }')
    [ -n "$url" ] && printf '%s' "$url" | openspot clipboard copy && openspot toast "Copied the link."
    ;;
  wake)
    tabs | while IFS="$(printf '\t')" read -r id at browser url title; do
      forget "$id" && open -b "$browser" "$url"
    done
    ;;
  snooze)
    snooze "" ""
    ;;
  due)
    value=$(value event.value)
    rest=${value#* }
    open -b "${value%% *}" "${rest%% *}"
    ;;
esac
