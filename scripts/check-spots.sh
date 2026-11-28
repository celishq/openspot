#!/bin/sh
. "$(dirname "$0")/checks.sh"
need $spot_folders
clocks=$(mktemp)
state=$(mktemp)
trap 'rm -f "$clocks" "$state"' EXIT
find spots store -name spot.toml -exec awk '/^[[:space:]]*\[/ { on = $0 ~ /^[[:space:]]*\[on\][[:space:]]*$/ } on && /^[[:space:]]*every[[:space:]]*=/ { print FILENAME; exit }' {} \; >"$clocks"
grep -rnE 'TMPDIR|/tmp([^A-Za-z0-9_]|$)|temporaryDirectory|NSTemporaryDirectory' $spot_folders | grep -v 'mktemp' | cut -d: -f1 >"$state"
compare spot-clocks "$clocks" "A shipped spot polls with a clock; see spots/AGENTS.md:"
polls=$?
compare spot-state "$state" "A spot keeps state outside OPENSPOT_DATA; see spots/AGENTS.md:"
keeps=$?
[ $polls -eq 0 ] && [ $keeps -eq 0 ] || exit 1
echo "Spots check passed."
