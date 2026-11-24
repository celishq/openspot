#!/bin/sh
# Puts the front tab of the browser in front in the panel's field, with its title, where Tab offers it to each spot that
# takes a link. It reads only when the panel opens over a browser.

# The words AppleScript uses for a browser's front tab and for its title, split by a tab: Safari's, or those of a
# browser built on Chromium.
tab_words() {
  case "$1" in
    com.apple.Safari|com.apple.SafariTechnologyPreview) printf 'current tab\tname' ;;
    *) printf 'active tab\ttitle' ;;
  esac
}

case "$1" in
  show)
    browser=$(lsappinfo info -only bundleid "$(lsappinfo front)" | sed -n 's/^.*bundleID="\([^"]*\)".*$/\1/p')
    [ -n "$browser" ] || exit 0
    words=$(tab_words "$browser")
    tab=$(osascript -e "tell application id \"$browser\" to set front_tab to ${words%%	*} of front window" \
      -e "tell application id \"$browser\" to return (URL of front_tab) & linefeed & (${words#*	} of front_tab)" 2>/dev/null)
    url=$(printf '%s\n' "$tab" | sed -n 1p)
    title=$(printf '%s\n' "$tab" | sed -n 2p)
    [ -n "$url" ] || exit 0
    openspot attachment add url="$url" title="${title:-$url}" app="$browser"
    ;;
esac
exit 0
