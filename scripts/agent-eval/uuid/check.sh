#!/bin/sh
. "$TASKS/checks.sh"
lint || exit 1
kept=$(pbpaste)
id=$(own_id)
"$OPENSPOT" --config "$OPENSPOT_CONFIG" spot run "$id" open </dev/null || "$OPENSPOT" --config "$OPENSPOT_CONFIG" spot run "$id" </dev/null
copied=$(pbpaste)
printf "%s" "$kept" | pbcopy
echo "copied: $copied"
[ "$copied" != "$kept" ] && printf "%s" "$copied" | grep -Eqi "^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$"
