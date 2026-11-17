#!/bin/sh
. "$TASKS/checks.sh"
lint || exit 1
shown=$("$OPENSPOT" spot run "$(own_id)" </dev/null)
echo "$shown"
printf "%s" "$shown" | grep -q "^field="
