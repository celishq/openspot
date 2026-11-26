#!/bin/sh
. "$TASKS/checks.sh"
lint || exit 1
shown=$("$OPENSPOT" --config "$OPENSPOT_CONFIG" spot run clock </dev/null)
echo "$shown"
for zone in Asia/Tokyo Europe/London; do
  printf "%s" "$shown" | grep -q -e "$(TZ=$zone date +%H:%M)" -e "$(TZ=$zone date -v-1M +%H:%M)" || exit 1
done
