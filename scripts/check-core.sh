#!/bin/sh
. "$(dirname "$0")/checks.sh"
need app/Core
if grep -rnE --include='*.swift' '^[[:space:]]*(@[[:alnum:]_]+(\([^)]*\))?[[:space:]]+)*import[[:space:]]' app/Core \
  | grep -vE 'import[[:space:]]+((typealias|struct|class|enum|protocol|let|var|func)[[:space:]]+)?(Foundation|CoreGraphics|CoreText|CryptoKit|ImageIO|CommonCrypto|JavaScriptCore|Observation|os|P256K|Security|Synchronization)([.[:space:]]|$)'; then
  echo "app/Core imports a module outside its list; see Core and Shell in AGENTS.md." >&2
  exit 1
fi
found=$(mktemp)
trap 'rm -f "$found"' EXIT
grep -rEo --include='*.swift' 'asyncAfter' app/Core | grep -v '^app/Core/Run/RunClock\.swift:' | tr ':' '\t' >"$found"
compare core-timers "$found" "app/Core arms a timer outside RunClock; take the clock of the runs, so that a test can move it:" || exit 1
echo "Core check passed."
