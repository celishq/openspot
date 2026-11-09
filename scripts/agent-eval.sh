#!/bin/sh
# Measures goal 5 of spec/README.md: a coding agent with only `openspot guide` and one sentence writes a spot that
# passes `openspot check --json` with [], so that it shows on the grid, on its first try.
# Usage: scripts/agent-eval.sh [tasks]. Each task runs `claude -p` once in an empty plugins folder of its own, and costs
# money, so run one task first. A stand-in for `openspot spot show` keeps the app closed and notes each try.
# It prints one line for each task, then the score, and writes them to .temp/agent-eval/result.txt.
set -e
cd "$(dirname "$0")/.."
out="$PWD/.temp/agent-eval"
rm -rf "$out/runs" "$out/result.txt"
mkdir -p "$out/bin"
(cd app && xcodegen generate >/dev/null)
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project app/Openspot.xcodeproj -scheme Openspot \
  -configuration Debug -derivedDataPath "$out/build" build -quiet >"$out/build.log" 2>&1 || { grep error: "$out/build.log"; exit 1; }
real="$out/build/Build/Products/Debug/Openspot.app/Contents/Helpers/openspot"
cat >"$out/bin/openspot" <<STAND
#!/bin/sh
if [ "\$1 \$2" = "spot show" ]; then echo "\$3" >> "\$OPENSPOT_CONFIG/shows.txt"; echo "Openspot shows \$3."; exit 0; fi
exec "$real" "\$@"
STAND
chmod +x "$out/bin/openspot"
passed=0
total=0
while IFS= read -r task; do
  total=$((total + 1))
  place="$out/runs/$total"
  mkdir -p "$place/plugins"
  (cd "$place/plugins" && OPENSPOT_CONFIG="$place" PATH="$out/bin:$PATH" claude -p \
    "Run \`openspot guide\` and read all of it. Then build an Openspot spot in this folder that $task." \
    --permission-mode acceptEdits --allowedTools "Bash Read Write Edit" </dev/null >"$place/agent.txt" 2>&1) || true
  OPENSPOT_CONFIG="$place" "$real" check --json "$place/plugins" >"$place/check.json" 2>&1 || true
  spots=$(find "$place/plugins" -maxdepth 2 -type f -perm -u+x | wc -l | tr -d ' ')
  if [ "$(cat "$place/check.json")" = "[]" ] && [ "$spots" -gt 0 ]; then
    passed=$((passed + 1))
    echo "pass  $task" | tee -a "$out/result.txt"
  else
    echo "fail  $task: $(cat "$place/check.json")" | tee -a "$out/result.txt"
  fi
done <<TASKS
$(head -n "${1:-5}" <<LIST
shows the time in Tokyo
lists the files on the Desktop, newest first, and opens the one that I pick
shows how full the main disk is
asks for a note and keeps each note in a file
copies a new UUID to the clipboard
LIST
)
TASKS
echo "$passed of $total passed" | tee -a "$out/result.txt"
