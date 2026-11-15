#!/bin/sh
. "$(dirname "$0")/checks.sh"
need app/Core app/Shell app/Client
found=$(mktemp)
trap 'rm -f "$found"' EXIT
grep -rnoE --include='*.swift' '(^|[^A-Za-z0-9_.])Process\(\)' app/Core app/Shell app/Client \
  | sed -E 's/^([^:]*):[0-9]+:.*/\1	Process()/' >"$found"
compare processes "$found" "Code starts a process on its own; run it through ScriptProcess, which has a limit and a stop:" || exit 1
echo "Processes check passed."
