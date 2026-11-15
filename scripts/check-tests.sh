#!/bin/sh
. "$(dirname "$0")/checks.sh"
need app/Tests
if grep -rEn --include='*.swift' 'homeDirectoryForCurrentUser|NSHomeDirectory|NSPasteboard\.general|Thread\.sleep|usleep\(' app/Tests; then
  echo "A test reads the person's state or blocks with a sleep; see Tests in AGENTS.md." >&2
  exit 1
fi
found=$(mktemp)
trap 'rm -f "$found"' EXIT
grep -rEo --include='*.swift' 'Task\.sleep|setenv\(' app/Tests | grep -v '^app/Tests/XCTestCase+Wait\.swift:' | tr ':' '\t' | tr -d '(' >"$found"
compare test-pauses "$found" "A test pauses with Task.sleep or changes the environment of the whole process; wait for a fact with wait(_:until:), and give a process its environment as a value:" || exit 1
echo "Tests check passed."
