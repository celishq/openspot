#!/bin/sh
. "$(dirname "$0")/checks.sh"
need app/Core
if grep -rnE --include='*.swift' '^[[:space:]]*(@[[:alnum:]_]+(\([^)]*\))?[[:space:]]+)*import[[:space:]]' app/Core \
  | grep -vE 'import[[:space:]]+((typealias|struct|class|enum|protocol|let|var|func)[[:space:]]+)?(Foundation|CoreGraphics|CoreText|CryptoKit|CommonCrypto|JavaScriptCore|Observation|os|P256K|Security|Synchronization)([.[:space:]]|$)'; then
  echo "app/Core imports a module outside its list; see Core and Shell in AGENTS.md." >&2
  exit 1
fi
echo "Core check passed."
