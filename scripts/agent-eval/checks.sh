ids() {
  "$OPENSPOT" spot list --json </dev/null | python3 -I -c '
import json, sys
print("\n".join(spot["id"] for spot in json.load(sys.stdin)))
'
}

own_id() {
  ids | grep -v '^openspot/' | head -n 1
}

lint() {
  found=$("$OPENSPOT" check spots --json "$PLACE/spots" </dev/null 2>&1)
  echo "check: $found"
  [ "$found" = "[]" ]
}

used() {
  cut -f 3 "$PLACE/calls.tsv" | grep -q "^$1"
}

answer() {
  tr -d ' \n' <answer.txt
}
