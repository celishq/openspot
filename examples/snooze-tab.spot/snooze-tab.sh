#!/bin/sh
# Snooze closes the front tab of the frontmost browser once the person picks a time on the snooze sheet, and the
# timer's reopen opens it again in that browser. The sheet starts with Snooze Current Tab, pinned, then lists each snoozed tab: Return opens
# it now, Copy Link copies its url, and Remove forgets it. Open All opens every one now. The rows also show in the main search.
# A timer calls reopen with the browser id, the url and the title; a tab snoozed for Someday is a timer with no time.
. "$OPENSPOT_SH"

# The words AppleScript uses for a browser's front tab and for its title, split by a tab, by bundle id: Safari's, or
# those of a browser built on Chromium. A browser it cannot read has none.
tab_words() {
  case "$1" in
    com.apple.Safari|com.apple.SafariTechnologyPreview) printf 'current tab\tname' ;;
    com.google.Chrome|com.google.Chrome.canary|company.thebrowser.Browser|com.brave.Browser|com.microsoft.edgemac|com.vivaldi.Vivaldi|com.operasoftware.Opera) printf 'active tab\ttitle' ;;
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
  words=$(tab_words "$1")
  [ -n "$words" ] || return
  osascript -e "tell application id \"$1\" to set front_tab to ${words%%	*} of front window" \
    -e "tell application id \"$1\" to return (URL of front_tab) & linefeed & (${words#*	} of front_tab)" 2>/dev/null
}

close_tab() {
  words=$(tab_words "$1")
  [ -n "$words" ] || return
  osascript -e "tell application id \"$1\" to close ${words%%	*} of front window" >/dev/null 2>&1
}

# Prints each snoozed tab as a line: id, time or someday, browser, url, title, split by tabs.
tabs() {
  openspot timer list 2>/dev/null | openspot_rows item at input.browser input.url input.title
}

forget() {
  openspot timer remove "$1" >/dev/null
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

# Snoozes the front tab of the frontmost browser until the time the person picks on the bound picker, and closes it. A
# title read earlier for the same browser names the picker; the tab itself is read after the pick, so the timer keeps
# the tab it closes.
snooze() {
  browser=$(front_id)
  if [ -z "$(tab_words "$browser")" ]; then
    echo "$(front_name) is not a browser that Snooze Tab can read. Use Safari, Chrome, Arc, Brave, Edge, Vivaldi or Opera." >&2
    exit 1
  fi
  if [ "$1" = "$browser" ] && [ -n "$2" ]; then
    at=$(openspot run picker.pick title="$2" --out until) || exit 0
  else
    at=$(openspot run picker.pick --out until) || exit 0
  fi
  tab=$(read_tab "$browser")
  url=$(printf '%s\n' "$tab" | sed -n 1p)
  title=$(printf '%s\n' "$tab" | sed -n 2p)
  [ -n "$url" ] || { echo "$(front_name) shows no tab." >&2; exit 1; }
  if [ -n "$title" ]; then
    openspot timer add "$at" reopen browser="$browser" url="$url" title="$title" >/dev/null || exit 1
  else
    openspot timer add "$at" reopen browser="$browser" url="$url" >/dev/null || exit 1
  fi
  close_tab "$browser"
  openspot toast "Snoozed the tab."
}

case "$1" in
  show)
    browser=$(front_id)
    tab=$(read_tab "$browser")
    url=$(printf '%s\n' "$tab" | sed -n 1p)
    title=$(printf '%s\n' "$tab" | sed -n 2p)
    printf 'button=remove\ntitle=Remove\nshortcut=cmd+backspace\n\nbutton=copy\ntitle=Copy Link\n'
    openspot_item current "Snooze Current Tab" "${title:-${url:-The front tab of your browser}}" moon.zzz
    printf 'pin=top\nhides=remove\nhides=copy\n'
    openspot_kv browser "$browser"
    [ -z "$title" ] || openspot_kv page "$title"
    tabs | while IFS="$(printf '\t')" read -r id at browser url title; do
      openspot_item "$id" "${title:-$url}" "$(when "$at")" "$(icon "$url")"
    done
    ;;
  press)
    item=$(value item)
    if [ "$item" = current ]; then
      snooze "$(value item.browser)" "$(value item.page)"
      exit
    fi
    tabs | awk -F '\t' -v id="$item" '$1 == id { print $3 "\t" $4 }' | while IFS="$(printf '\t')" read -r browser url; do
      forget "$item" && open -b "$browser" "$url"
    done
    ;;
  remove)
    item=$(value item)
    [ -n "$item" ] && [ "$item" != current ] && forget "$item"
    ;;
  copy)
    url=$(tabs | awk -F '\t' -v id="$(value item)" '$1 == id { print $4 }')
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
  reopen)
    open -b "$(value browser)" "$(value url)"
    ;;
esac
