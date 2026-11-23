#!/bin/sh
. "$(dirname "$0")/checks.sh"
need app/Help
found=$(mktemp)
trap 'rm -f "$found"' EXIT
guides=$(ls GUIDE.md USING.md 2>/dev/null)
awk '
  FNR == 1 { fence = 0; section = ""; learned = 1; last = "" }
  /^```/ {
    if (!fence && $0 ~ /^```(toml|js|swift)$/) named(FILENAME)
    if (!fence && $0 == "```sh") { pending = FILENAME; shell = 1 } else shell = 0
    fence = !fence; next
  }
  fence {
    if (shell && pending != "" && $0 ~ /^#!/) named(pending)
    shell = 0; pending = ""; next
  }
  /^#+ / {
    heading = $0; sub(/^#+ /, "", heading)
    if ($0 ~ /^##+ / && heading ~ /^(The|A|An|How|What|Why|When|Where|Which|Who|Your)( |$)/) print FILENAME " heading: " heading
    if ($0 ~ /^## / && FILENAME == "GUIDE.md") { ended(); section = heading; learned = 0 }
  }
  /^Learn more in / { learned = 1 }
  /^[^[:space:]]/ { if ($0 !~ /^<!--/) last = $0 }
  END { ended() }
  function ended() { if (section != "" && !learned) print "GUIDE.md section with no Learn more: " section }
  function named(file) {
    if (file == "GUIDE.md" && last !~ /`[^` ]+\.(toml|sh|js|swift)`:?$/) print file " unnamed file after: " last
  }
' $guides >>"$found"
awk '
  FNR == 1 { fence = 0 }
  /^```/ { fence = !fence; next }
  fence || !/^\|/ || /^\| *-/ { next }
  {
    line = $0
    gsub(/\\\|/, "", line)
    n = split(line, cells, "|")
    for (i = 2; i < n; i++) {
      cell = cells[i]
      gsub(/``[^`]*``/, "x", cell)
      gsub(/`[^`]*`/, "x", cell)
      if (cell ~ /[.!?] +[A-Z]/) { first = cells[2]; gsub(/^ +| +$/, "", first); print FILENAME " cell of two sentences: " first; break }
    }
  }
' $guides PROTOCOL.md docs/protocol/*.md app/Help/*.md >>"$found"
awk '
  FNR == 1 { if (file != "") counted(); file = FILENAME; words = 0; fence = 0 }
  /^```/ { fence = !fence; next }
  !fence { for (i = 1; i <= NF; i++) if ($i ~ /[A-Za-z0-9]/) words++ }
  END { counted() }
  function counted() { limit = file == "GUIDE.md" ? 1200 : file ~ /\/01-[^\/]*$/ ? 1500 : 800; if (words > limit) print file " has " words " words, over " limit }
' GUIDE.md docs/protocol/*.md >>"$found"
compare docs "$found" "A doc breaks a rule of Docs in AGENTS.md:" || exit 1
echo "Docs check passed."
