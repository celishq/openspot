#!/bin/sh
. "$(dirname "$0")/checks.sh"
need app/Shell
found=$(mktemp)
trap 'rm -f "$found"' EXIT
grep -rlE --include='*.swift' 'RoundedRectangle\(' app/Shell | grep -v '^app/Shell/Surface/SpotRoundShape\.swift$' >"$found"
compare shapes "$found" "A view builds a rounded shape of its own. Take the one shape of its surface, a SpotRoundShape or a SpotSurfaceShape, and inset it:" || exit 1
echo "Shapes check passed."
