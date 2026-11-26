#!/bin/sh
set -e
cd "$(dirname "$0")/.."
root="$PWD"
tasks="$root/scripts/agent-eval"
out="$root/.temp/agent-eval"
real="$out/build/Build/Products/Debug/Openspot Nightly.app/Contents/Helpers/openspot"

if [ "$1" = "--run" ]; then
  set +e
  label=$2 task=$3 n=$4
  place="$out/$label/runs/$task-$n"
  rm -rf "$place"
  mkdir -p "$place/spots" "$place/work"
  if [ -f "$tasks/$task/ask" ]; then
    [ ! -d "$tasks/$task/seed" ] || cp -R "$tasks/$task/seed/." "$place/spots/"
    eval "set -- $(cat "$tasks/$task/ask")"
    prompt=$("$real" --config "$place" prompt "$@" </dev/null | sed "s|\"$real\"|openspot|g")
  else
    prompt="You have the \`openspot\` command of the Openspot Mac app on your PATH. $(cat "$tasks/$task/prompt")"
  fi
  printf '%s\n' "$prompt" >"$place/prompt.txt"
  if [ -f "$tasks/$task/live" ]; then
    until mkdir "$out/live.lock" 2>/dev/null; do sleep 2; done
    trap 'rmdir "$out/live.lock" 2>/dev/null' EXIT
  fi
  start=$(date +%s)
  (cd "$place/work" && OPENSPOT_CONFIG="$place" PATH="$out/bin:$PATH" perl -e 'alarm shift; exec @ARGV' 900 \
    claude -p "$prompt" --model sonnet --output-format json --permission-mode acceptEdits \
    --allowedTools "Bash Read Write Edit" </dev/null >"$place/report.json" 2>"$place/agent.err")
  seconds=$(($(date +%s) - start))
  touch "$place/calls.tsv"
  (cd "$place/work" && PLACE="$place" OPENSPOT="$real" OPENSPOT_CONFIG="$place" TASKS="$tasks" \
    perl -e 'alarm shift; exec @ARGV' 300 sh "$tasks/$task/check.sh" >"$place/check.txt" 2>&1)
  result=$([ $? -eq 0 ] && echo pass || echo fail)
  "$real" --config "$place" app quit >/dev/null 2>&1 </dev/null
  python3 -I "$tasks/run.py" "$place" "$task" "$n" "$result" "$seconds" >>"$out/$label/runs.tsv"
  echo "$result  $task #$n  (${seconds}s)"
  exit 0
fi

label=${1:-base}
repeats=${2:-3}
picked=$(cd "$tasks" && for t in */; do printf '%s ' "${t%/}"; done)
if [ $# -gt 2 ]; then
  shift 2
  picked=$*
fi
rm -rf "${out:?}/$label"
mkdir -p "$out/bin" "$out/$label"
rmdir "$out/live.lock" 2>/dev/null || true
(cd app && xcodegen generate >/dev/null)
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project app/Openspot.xcodeproj -scheme Openspot \
  -configuration Debug -derivedDataPath "$out/build" build -quiet >"$out/build.log" 2>&1 || { grep error: "$out/build.log"; exit 1; }
sed "s|@REAL@|$real|" "$tasks/openspot" >"$out/bin/openspot"
chmod +x "$out/bin/openspot"
printf 'task\tn\tresult\tseconds\tturns\tcost\tcalls\tusage\thangs\thelp\n' >"$out/$label/runs.tsv"
git rev-parse --short HEAD >"$out/$label/commit"
n=1
while [ "$n" -le "$repeats" ]; do
  for task in $picked; do echo "$task $n"; done
  n=$((n + 1))
done | xargs -P "${PARALLEL:-4}" -n 2 sh "$0" --run "$label" &
runs=$!
trap 'kill $runs 2>/dev/null; pkill -f "$out/build/" 2>/dev/null; exit 130' INT TERM
wait $runs
python3 -I "$tasks/summary.py" "$out/$label/runs.tsv" | tee "$out/$label/summary.txt"
