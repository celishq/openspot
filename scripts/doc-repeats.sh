#!/bin/sh
set -e
cd "$(dirname "$0")/.."
least=${1:-6}
docs=$(ls *.md app/*.md app/Help/*.md)

awk -v least="$least" '
function flush() {
  if (text != "") {
    n = split(text, parts, /[.!?] +|[.!?]$/)
    for (p = 1; p <= n; p++) {
      line = tolower(parts[p])
      gsub(/\]\([^)]*\)/, " ", line)
      gsub(/\x27/, "", line)
      gsub(/[^a-z0-9.=_<>\/-]+/, " ", line)
      gsub(/^ +| +$/, "", line)
      count = split(line, w, " ")
      if (count < least) continue
      units++
      where[units] = start
      size[units] = count
      for (i = 1; i <= count; i++) word[units, i] = w[i]
      for (i = 1; i + least - 1 <= count; i++) {
        key = w[i]
        for (j = 1; j < least; j++) key = key " " w[i + j]
        if (!((key, units) in seen)) { seen[key, units] = 1; holders[key] = holders[key] " " units }
      }
    }
  }
  text = ""
}
FNR == 1 { flush(); fence = 0 }
/^```/ { flush(); fence = !fence; next }
fence { next }
/^[ \t]*$/ || /^\|/ || /^</ || /^!\[/ || substr($0, 1, 1) == "#" { flush(); next }
/^[ \t]*([-*]|[0-9]+\.) / { flush() }
{
  if (text == "") start = FILENAME ":" FNR
  sub(/^[ \t]*([-*]|[0-9]+\.) /, "")
  text = text " " $0
}
END {
  flush()
  for (key in holders) {
    m = split(holders[key], ids, " ")
    for (a = 1; a <= m; a++) for (b = a + 1; b <= m; b++) pair[ids[a] + 0, ids[b] + 0] = 1
  }
  for (k in pair) {
    split(k, ab, SUBSEP)
    x = ab[1]; y = ab[2]
    best = 0; end = 0
    for (i = 1; i <= size[x]; i++) for (j = 1; j <= size[y]; j++) {
      run[i, j] = word[x, i] == word[y, j] ? run[i - 1, j - 1] + 1 : 0
      if (run[i, j] > best) { best = run[i, j]; end = i }
    }
    delete run
    shared = ""
    for (i = end - best + 1; i <= end; i++) shared = shared (shared == "" ? "" : " ") word[x, i]
    printf "%d\t%s\t%s\t%s\n", best, where[x], where[y], shared
  }
}
' $docs | sort -t "$(printf '\t')" -k1,1nr -k2,2 | awk -F '\t' '{ printf "%2d words  %s  ~  %s\n           %s\n", $1, $2, $3, $4 }'
