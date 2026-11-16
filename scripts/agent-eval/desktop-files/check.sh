#!/bin/sh
. "$TASKS/checks.sh"
lint || exit 1
shown=$("$OPENSPOT" spot run "$(own_id)" </dev/null)
echo "$shown"
newest=$(ls -t "$HOME/Desktop" | head -n 1)
[ -z "$newest" ] && exit 0
first=$(printf "%s\n" "$shown" | grep -m 1 "^title=")
echo "newest: $newest; first: $first"
printf "%s" "$first" | grep -qF "${newest%.*}"
