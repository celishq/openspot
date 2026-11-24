#!/bin/sh
. "$(dirname "$0")/checks.sh"
need app/Core app/Shell
found=$(mktemp)
methods=$(mktemp)
trap 'rm -f "$found" "$methods"' EXIT
find app/Core -name '*.swift' | sort | while read -r file; do
  awk -v f="$file" '
    function count(s, c,  t) { t = s; return gsub(c, "", t) }
    depth > 0 {
      if ($0 ~ /(^|[^A-Za-z0-9_])change\(/) print f "\tsetter of " name
      depth += count($0, "\\{") - count($0, "\\}")
      next
    }
    /(^|[^A-Za-z0-9_])var[[:space:]]+[A-Za-z_]/ {
      name = $0
      sub(/.*(^|[^A-Za-z0-9_])var[[:space:]]+/, "", name)
      sub(/[^A-Za-z0-9_].*/, "", name)
    }
    match($0, /(didSet|willSet|(^|[^A-Za-z0-9_])set(\([A-Za-z_]+\))?)[[:space:]]*\{/) {
      rest = substr($0, RSTART)
      if (rest ~ /(^|[^A-Za-z0-9_])change\(/) print f "\tsetter of " name
      depth = count(rest, "\\{") - count(rest, "\\}")
    }
  ' "$file"
done >"$found"
grep -lE '(extension|class) SpotsModel([^A-Za-z0-9_]|$)' $(find app/Core -name '*.swift' | sort) | xargs awk '
  function flush() {
    if (fn != "") print fn "\t" pub "\t" first "\t" lines
    fn = ""
  }
  /^    [a-z@ ]*func [A-Za-z_]/ {
    flush()
    fn = $0; sub(/.*func /, "", fn); sub(/[^A-Za-z0-9_].*/, "", fn)
    pub = $0 ~ /public / ? "public" : "inner"
    first = ""; lines = 0
    next
  }
  fn != "" && /^    \}/ { flush(); next }
  fn != "" && /[^[:space:]]/ {
    lines++
    if (lines == 1) { first = $0; sub(/^[[:space:]]+/, "", first) }
  }
  END { flush() }
' | awk -F '\t' '
  { name[NR] = $1; pub[NR] = $2; first[NR] = $3; lines[NR] = $4 }
  END {
    for (i = 1; i <= NR; i++) if (first[i] ~ /^((return|_ =) )?asOnePress[[:space:]]*\{/) wraps[name[i]] = 1
    for (i = 1; i <= NR; i++) {
      if (wraps[name[i]] || lines[i] != 1) continue
      call = first[i]; sub(/^((return|_ =) )?(self\.)?/, "", call)
      if (call ~ /^[A-Za-z_][A-Za-z0-9_]*\(/) { sub(/\(.*/, "", call); if (wraps[call]) wraps[name[i]] = 1 }
    }
    for (i = 1; i <= NR; i++) if (pub[i] == "public" && !wraps[name[i]]) open[name[i]] = 1
    for (n in open) print n
  }
' >"$methods"
find app/Shell -name '*.swift' ! -path 'app/Shell/Tools/*' | sort | xargs awk -v list="$methods" '
  BEGIN { while ((getline n < list) > 0) open[n] = 1 }
  function count(s, c,  t) { t = s; return gsub(c, "", t) }
  function calls(s,  m) {
    while (match(s, /model\.[A-Za-z_][A-Za-z0-9_]*/)) {
      m = substr(s, RSTART + 6, RLENGTH - 6)
      if (m in open) print "SpotsModel." m
      s = substr(s, RSTART + RLENGTH)
    }
  }
  FNR == 1 { depth = 0 }
  depth > 0 {
    calls($0)
    depth += count($0, "\\{") - count($0, "\\}")
    next
  }
  match($0, /(onTapGesture|onLongPressGesture|TapGesture|DragGesture|\.onEnded|\.onChanged|Button[[:space:]]*[({]|onKeyPress|onDrop|dropDestination|onSubmit|onMoveCommand|onExitCommand|onCommand|(action|perform|set|on[A-Z][A-Za-z]*):[[:space:]]*\{?[[:space:]]*model\.|(action|perform|set|onTap|onPress|onDrop|onSubmit):[[:space:]]*\{)/) {
    rest = substr($0, RSTART)
    if (rest ~ /^onChange|^onAppear|^onDisappear/) next
    calls(rest)
    depth = count(rest, "\\{") - count(rest, "\\}")
  }
' | sort -u >>"$found"
compare presses "$found" "A setter writes through change, or a press of Shell reaches a SpotsModel method that does not start with asOnePress (see The press in AGENTS.md):" || exit 1
echo "Presses check passed."
