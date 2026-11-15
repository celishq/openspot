#!/bin/sh
. "$(dirname "$0")/checks.sh"
need spots examples
clocks=$(mktemp)
state=$(mktemp)
trap 'rm -f "$clocks" "$state"' EXIT
grep -rlE '^(#|//)[[:space:]]*on=clock\.' spots >"$clocks"
grep -rnE 'TMPDIR|/tmp([^A-Za-z0-9_]|$)|temporaryDirectory|NSTemporaryDirectory' spots examples | grep -v 'mktemp' | cut -d: -f1 >"$state"
compare spot-clocks "$clocks" "A shipped spot polls with a clock; see spots/AGENTS.md:"
polls=$?
compare spot-state "$state" "A spot keeps state outside OPENSPOT_DATA; see spots/AGENTS.md:"
keeps=$?
[ $polls -eq 0 ] && [ $keeps -eq 0 ] || exit 1
echo "Spots check passed."
