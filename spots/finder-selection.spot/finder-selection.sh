#!/bin/sh
# Puts the files selected in the front Finder window in the panel's field, where Tab offers them to each spot that
# takes them. It reads only when the panel opens over Finder.
case "$1" in
  show)
    picked=$(osascript -e 'tell application "Finder" to set picked to selection as alias list' \
      -e 'set out to ""' -e 'repeat with one in picked' -e 'set out to out & POSIX path of one & linefeed' -e 'end repeat' \
      -e 'return out' 2>/dev/null)
    set --
    while IFS= read -r path; do
      [ -n "$path" ] && set -- "$@" "file=${path%/}"
    done <<EOF_PATHS
$picked
EOF_PATHS
    [ $# -gt 0 ] && openspot context add "$@" app=com.apple.finder
    ;;
esac
exit 0
