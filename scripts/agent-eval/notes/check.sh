#!/bin/sh
. "$TASKS/checks.sh"
lint || exit 1
shown=$("$OPENSPOT" --config "$OPENSPOT_CONFIG" spot run "$(own_id)" </dev/null)
echo "$shown"
printf "%s" "$shown" | grep -q "^field="
