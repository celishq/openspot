#!/bin/sh
set -e
cd "$(dirname "$0")/.."
untested=scripts/rules-untested.txt
ids=$(mktemp); named=$(mktemp); left=$(mktemp)
trap 'rm -f "$ids" "$named" "$left"' EXIT

grep -oE '^\| [A-Z][0-9]+ ' app/RULES.md | tr -d '| ' | LC_ALL=C sort >"$ids"
twice=$(uniq -d "$ids")
if [ -n "$twice" ]; then
  echo "$twice" >&2
  echo "A rule ID is given twice in app/RULES.md." >&2
  exit 1
fi

grep -rhoE 'func test_[A-Za-z0-9_]+' app/Tests | grep -oE '_[A-Z][0-9]+(_|$)' | tr -d '_' | LC_ALL=C sort -u >"$named"
unknown=$(LC_ALL=C comm -13 "$ids" "$named")
if [ -n "$unknown" ]; then
  echo "$unknown" >&2
  echo "A test names a rule ID that app/RULES.md lacks." >&2
  exit 1
fi

LC_ALL=C comm -23 "$ids" "$named" >"$left"
if [ "$1" = "--write" ]; then cp "$left" "$untested"; echo "Wrote $(wc -l <"$untested" | tr -d ' ') IDs to $untested."; exit 0; fi
new=$(LC_ALL=C sort "$untested" | LC_ALL=C comm -23 "$left" -)
gone=$(LC_ALL=C sort "$untested" | LC_ALL=C comm -13 "$left" -)
if [ -n "$new" ]; then
  echo "$new" >&2
  echo "No test names this rule, as in func test_A4_searchStaysUntilEsc; see Comments in AGENTS.md." >&2
  exit 1
fi
if [ -n "$gone" ]; then
  echo "$gone" >&2
  echo "A test now names these rules; remove them from $untested." >&2
  exit 1
fi
echo "Rules check passed ($(wc -l <"$untested" | tr -d ' ') rules with no test left)."
