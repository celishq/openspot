#!/bin/sh
. "$TASKS/checks.sh"
lint || exit 1
plain || exit 1
kept=$(pbpaste)
id=$(own_id)
for call in open "" $(sed -n 's/^\[actions\.\([^]]*\)\]$/\1/p' "$PLACE"/spots/*/spot.toml); do
  "$OPENSPOT" --config "$OPENSPOT_CONFIG" spot run "$id" $call </dev/null
  copied=$(pbpaste)
  [ "$copied" = "$kept" ] || break
done
printf "%s" "$kept" | pbcopy
echo "copied: $copied"
[ "$copied" != "$kept" ] && printf "%s" "$copied" | grep -Eqi "^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$"
