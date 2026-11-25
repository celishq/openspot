#!/bin/sh
. "$(dirname "$0")/checks.sh"
need app/Tests
if grep -rEn --include='*.swift' 'homeDirectoryForCurrentUser|NSHomeDirectory|NSPasteboard\.general|Thread\.sleep|usleep\(' app/Tests; then
  echo "A test reads the person's state or blocks with a sleep; see Tests in AGENTS.md." >&2
  exit 1
fi
if grep -rEn --include='*.swift' '(wait\(|for _ in .* where ).*(fileExists\(|(saved|read)\([^)]*\) != nil|contentsOf[^}]*\) != nil)' app/Tests; then
  echo "A test waits for a file to exist, but a child makes a file before it writes it; wait for its whole lines with lines(at:); see Tests in AGENTS.md." >&2
  exit 1
fi
if grep -rEn --include='*.swift' 'pgrep|proc_listallpids' app/Tests | grep -v '^app/Tests/XCTestCase+Processes\.swift:' | grep -v 'pgrep -P \$\$'; then
  echo "A test looks for processes outside its own; find them with children(running:), children(matching:) or processes(tagged:); see Tests in AGENTS.md." >&2
  exit 1
fi
if find app/Tests -name '*.swift' ! -name 'XCTestCase+Files.swift' -exec awk '
  FNR == 1 { prev = "" }
  prev ~ /(func|var) .*\{[[:space:]]*$/ && /^[[:space:]]*(return )?FileManager\.default\.fileExists\(atPath: [^,]*\)[[:space:]]*$/ { print FILENAME ":" FNR ": " $0; found = 1 }
  /(func|var) [^=]*\{[[:space:]]*(return )?FileManager\.default\.fileExists\(atPath: [^,]*\)[[:space:]]*\}/ { print FILENAME ":" FNR ": " $0; found = 1 }
  { prev = $0 }
  END { exit !found }
' {} + | grep .; then
  echo "A test wraps fileExists, which hides a wait for a file from this check; use placed(at:) or lines(at:); see Tests in AGENTS.md." >&2
  exit 1
fi
found=$(mktemp)
trap 'rm -f "$found"' EXIT
if grep -rEn --include='*.swift' 'Task\.sleep|setenv\(|Date\(\)\.timeIntervalSince|ContinuousClock\.now|Task\.yield' app/Tests | grep -v '^app/Tests/XCTestCase+Wait\.swift:'; then
  echo "A test pauses or reads the real clock, or changes the environment of the whole process; move a FakeClock, wait for a fact with wait(_:until:), and give a process its environment as a value; see Tests in AGENTS.md." >&2
  exit 1
fi
grep -rEn --include='*.swift' 'XCTAssert(GreaterThan|LessThan)(OrEqual)?\(.*(\.cpu|CPUTIME).*, [0-9.]*[1-9]' app/Tests | cut -d: -f1 | sed 's/$/	cpu bound/' >"$found"
compare test-speeds "$found" "A test bounds a CPU time by a number, which a faster or busier Mac crosses; give the run a thread clock with FakeClock(threadStep:):" || exit 1
echo "Tests check passed."
