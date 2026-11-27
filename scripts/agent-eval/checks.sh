ids() {
  "$OPENSPOT" --config "$OPENSPOT_CONFIG" spot list --json </dev/null | python3 -I -c '
import json, sys
print("\n".join(spot["id"] for spot in json.load(sys.stdin)))
'
}

own_id() {
  ids | grep -v '^openspot/' | head -n 1
}

lint() {
  found=$("$OPENSPOT" --config "$OPENSPOT_CONFIG" check spots --json "$PLACE/spots" </dev/null 2>/dev/null)
  echo "check: $found"
  [ "$found" = "[]" ]
}

ways() {
  "$OPENSPOT" --config "$OPENSPOT_CONFIG" check spots --json "$PLACE/spots" </dev/null 2>&1 >/dev/null
}

plain() {
  found=$(ways)
  echo "ways: $found"
  [ -z "$found" ]
}

used() {
  cut -f 3 "$PLACE/calls.tsv" | grep -q "^$1"
}

answer() {
  tr -d ' \n' <answer.txt
}
