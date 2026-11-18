#!/bin/sh
. "$(dirname "$0")/checks.sh"
need app/Core app/Shell app/Client app/Shared
found=$(mktemp)
trap 'rm -f "$found"' EXIT
grep -rnoE --include='*.swift' '(^|[^A-Za-z0-9_.])(Process\(\)|posix_spawn\()' app/Core app/Shell app/Client app/Shared \
  | grep -v '^app/Core/Script/ScriptProcess.swift:' \
  | sed -E 's/^([^:]*):[0-9]+:.*(Process\(\)|posix_spawn\().*/\1	\2/' >"$found"
compare processes "$found" "Code starts a process on its own; run it through ScriptProcess, which has a limit and a stop:" || exit 1
echo "Processes check passed."
