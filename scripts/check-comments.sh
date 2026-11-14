#!/bin/sh
set -e
cd "$(dirname "$0")/.."
allowed=scripts/comments-allowed.txt
found=$(mktemp)
trap 'rm -f "$found" "$found.a"' EXIT

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

LC_ALL=C sort "$found" -o "$found"
if [ "$1" = "--write" ]; then cp "$found" "$allowed"; echo "Wrote $(wc -l <"$allowed" | tr -d ' ') lines to $allowed."; exit 0; fi
LC_ALL=C sort "$allowed" >"$found.a"

new=$(LC_ALL=C comm -23 "$found" "$found.a")
gone=$(LC_ALL=C comm -13 "$found" "$found.a")
if [ -n "$new" ]; then
  echo "$new" >&2
  echo "A comment in code or scripts; see Comments in AGENTS.md." >&2
  exit 1
fi
if [ -n "$gone" ]; then
  echo "$gone" >&2
  echo "These lines of $allowed are gone from the code; remove them from it." >&2
  exit 1
fi
echo "Comments check passed ($(wc -l <"$allowed" | tr -d ' ') old comments left)."
