#!/bin/sh
set -e
cd "$(dirname "$0")/.."
found=$(mktemp)
trap 'rm -f "$found"' EXIT

swift_files=$(find app scripts -name '*.swift' -not -path '*/Openspot.xcodeproj/*' | sort)
script_files=$(find scripts -name '*.sh' -o -name '*.py' | sort; echo Makefile)

for f in $swift_files; do
  awk -v f="$f" '
    { line = $0 }
    /"""/ { n = gsub(/"""/, "&", line); if (n % 2 == 1) { inraw = !inraw; next } }
    inraw { next }
    /^[ \t]*\/\/ @todo #[0-9A-Za-z-]+/ { next }
    /^[ \t]*(\/\/|\/\*|\*)/ { sub(/^[ \t]+/, ""); print f "\t" $0; next }
    {
      gsub(/#".*"#/, "", line)
      q = 0
      for (i = 1; i < length(line); i++) {
        c = substr(line, i, 1)
        if (c == "\\") { i++; continue }
        if (c == "\"") q = !q
        if (!q && substr(line, i, 2) == "//" && substr(line, i - 1, 1) != ":") { s = substr(line, i); print f "\t" s; break }
      }
    }
  ' "$f" >>"$found"
done

for f in $script_files; do
  awk -v f="$f" '
    NR == 1 && /^#!/ { next }
    heredoc != "" { if ($0 ~ "^[ \t]*" heredoc "$") heredoc = ""; next }
    /<<-?[ \t]*["'"'"']?[A-Za-z_]+/ { match($0, /<<-?[ \t]*["'"'"']?[A-Za-z_]+/); h = substr($0, RSTART, RLENGTH); gsub(/[<\-"'"'"' \t]/, "", h); heredoc = h }
    f ~ /\.py$/ && /^[ \t]*"""/ { print f "\t" $0; if (gsub(/"""/, "&") == 1) indoc = 1; next }
    indoc { print f "\t" $0; if (/"""/) indoc = 0; next }
    /^[ \t]*#/ { sub(/^[ \t]+/, ""); print f "\t" $0; next }
    /[ \t]#[ \t]/ {
      q = 0; s = 0
      for (i = 1; i <= length($0); i++) {
        c = substr($0, i, 1)
        if (c == "\\") { i++; continue }
        if (c == "\"" && s == 0) q = !q
        if (c == "'"'"'" && q == 0) s = !s
        if (!q && !s && c == "#" && substr($0, i - 1, 1) ~ /[ \t]/) { print f "\t" substr($0, i); break }
      }
    }
  ' "$f" >>"$found"
done

if [ -s "$found" ]; then
  cat "$found" >&2
  echo "A comment in code or scripts; see Comments in AGENTS.md." >&2
  exit 1
fi
echo "Comments check passed."
