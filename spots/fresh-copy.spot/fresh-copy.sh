#!/bin/sh
# Puts what you copied in the last 2 minutes in the panel's field, as a link or as text, where Tab offers it to each spot
# that takes it. It keeps a digest of the clipboard and the time it first saw it in its data folder.
. "$OPENSPOT_SH"
seen="$OPENSPOT_DATA/seen"
fresh=120

case "$1" in
  show)
    copied=$(pbpaste 2>/dev/null | head -c 100000)
    [ -n "$(printf '%s' "$copied" | tr -d '[:space:]')" ] || exit 0
    digest=$(printf '%s' "$copied" | shasum | cut -d ' ' -f 1)
    now=$(date +%s)
    if [ "$(sed -n 1p "$seen" 2>/dev/null)" != "$digest" ]; then
      printf '%s\n%s\n' "$digest" "$now" > "$seen.$$" && mv "$seen.$$" "$seen"
    fi
    first=$(sed -n 2p "$seen" 2>/dev/null)
    [ $((now - ${first:-0})) -lt $fresh ] || exit 0
    if printf '%s' "$copied" | grep -Eq '^https?://[^[:space:]]+$'; then
      openspot context add url="$copied" title="Copied link"
    else
      openspot context add text="$copied" title="Copied text"
    fi
    ;;
esac
exit 0
