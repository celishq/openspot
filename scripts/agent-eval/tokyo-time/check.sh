#!/bin/sh
. "$TASKS/checks.sh"
lint || exit 1
plain || exit 1
shown=$("$OPENSPOT" --config "$OPENSPOT_CONFIG" spot run "$(own_id)" </dev/null)
echo "$shown"
now=$(TZ=Asia/Tokyo date +%H:%M)
before=$(TZ=Asia/Tokyo date -v-1M +%H:%M)
printf "%s" "$shown" | grep -q -e "$now" -e "$before"
