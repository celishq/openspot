#!/bin/sh
. "$(dirname "$0")/checks.sh"
need app/Core app/Shell app/Client
found=$(mktemp)
trap 'rm -f "$found"' EXIT
find app/Core app/Shell app/Client -name '*.swift' | sort | while read -r file; do
  awk -v f="$file" '
    BEGIN {
      n = split(f, part, "/"); base = part[n]; sub(/\.swift$/, "", base); sub(/\+.*/, "", base)
      disk = "FileManager\\.default\\.(fileExists|contents|attributesOfItem|enumerator|subpaths|destinationOfSymbolicLink|isReadable|isExecutable)|(Data|String|NSData|NSImage|NSDictionary)\\(contentsOf|contentsOfFile|resourceValues\\(|[^A-Za-z_.]l?stat\\(|\\.scan\\(\\)|\\.read\\(\\)"
    }
    function count(s, c,  t) { t = s; return gsub(c, "", t) }
    depth > 0 {
      if (!hit && $0 ~ disk) { print f "\t" name; hit = 1 }
      depth += count($0, "\\{") - count($0, "\\}")
      next
    }
    /^[[:space:]]*(@[[:alnum:]_]+[[:space:]]+)*((public|private|fileprivate|internal|open|nonisolated|static|class|override|final)[[:space:]]+)*var[[:space:]]+[A-Za-z_][A-Za-z0-9_]*[[:space:]]*:[^=]*\{.*\}[[:space:]]*$/ && $0 ~ disk {
      name = $0
      sub(/.*var[[:space:]]+/, "", name)
      sub(/[^A-Za-z0-9_].*/, "", name)
      print f "\t" name
      next
    }
    /^[[:space:]]*(@[[:alnum:]_]+[[:space:]]+)*((public|private|fileprivate|internal|open|nonisolated|static|class|override|final)[[:space:]]+)*var[[:space:]]+[A-Za-z_][A-Za-z0-9_]*[[:space:]]*:[^=]*\{[[:space:]]*$/ ||
    /^[[:space:]]*(@[[:alnum:]_]+[[:space:]]+)*((public|private|fileprivate|internal|open|nonisolated|override|final)[[:space:]]+)*static[[:space:]]+func[[:space:]].*->[[:space:]]*[A-Za-z_][A-Za-z0-9_]*\??[[:space:]]*\{[[:space:]]*$/ {
      name = $0
      if (name ~ /static[[:space:]]+func/) {
        if (name !~ ("->[[:space:]]*(Self|" base ")\\??[[:space:]]*\\{")) next
        sub(/.*func[[:space:]]+/, "", name)
      } else sub(/.*var[[:space:]]+/, "", name)
      sub(/[^A-Za-z0-9_].*/, "", name)
      hit = 0
      depth = count($0, "\\{") - count($0, "\\}")
    }
  ' "$file"
done >"$found"
compare getters "$found" "A getter or a static factory reads the disk; move the read into a method named for it (see Where work lives in AGENTS.md):" || exit 1
echo "Getters check passed."
