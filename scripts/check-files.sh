#!/bin/sh
. "$(dirname "$0")/checks.sh"
need app
found=$(mktemp)
trap 'rm -f "$found"' EXIT
find app -name '*.swift' -not -path '*/Openspot.xcodeproj/*' -not -name 'main.swift' -not -name '*+*' | sort | while read -r file; do
  awk -v f="$file" '
    BEGIN { n = split(f, part, "/"); base = part[n]; sub(/\.swift$/, "", base) }
    /^(@[[:alnum:]_]+(\([^)]*\))?[[:space:]]+)*((public|private|fileprivate|internal|open|final|nonisolated|indirect)[[:space:]]+)*(class|struct|enum|protocol|actor)[[:space:]]+[A-Za-z_]/ {
      if ($0 ~ /(^|[[:space:]])(private|fileprivate)[[:space:]]/) next
      name = $0
      sub(/.*(class|struct|enum|protocol|actor)[[:space:]]+/, "", name)
      sub(/[^A-Za-z0-9_].*/, "", name)
      count++
      if (name == base) own = 1
    }
    END { if (!own || count > 1) print f }
  ' "$file"
done >"$found"
compare files "$found" "A file does not hold one primary type named as the file (see Writing in AGENTS.md):" || exit 1
echo "Files check passed."
