ids() {
  { "$OPENSPOT" spot list --json 2>/dev/null || "$OPENSPOT" spot list; } </dev/null | python3 -I -c '
import json, sys
text = sys.stdin.read()
try:
    print("\n".join(spot["id"] for spot in json.loads(text)))
except ValueError:
    print("\n".join(line[5:] for line in text.splitlines() if line.startswith("spot=")))
'
}

own_id() {
  ids | grep -v '^openspot/' | head -n 1
}

lint() {
  found=$("$OPENSPOT" check --json "$PLACE/spots" </dev/null 2>&1)
  [ $? -eq 2 ] && found=$("$OPENSPOT" check spots --json "$PLACE/spots" </dev/null 2>&1)
  echo "check: $found"
  [ "$found" = "[]" ]
}

used() {
  cut -f 3 "$PLACE/calls.tsv" | grep -q "^$1"
}

answer() {
  tr -d ' \n' <answer.txt
}
