#!/bin/sh
. "$TASKS/checks.sh"
lint || exit 1
made=$(cat "$TASKS/new-spot-build/build")
grep -qE '^state *= *"draft"' "$PLACE/spots/$made.spot/spot.toml" || { echo "the draft line is gone"; exit 1; }
[ "$(ls -d "$PLACE"/spots/*.spot | wc -l | tr -d ' ')" = 1 ] || { echo "another spot folder"; exit 1; }
steps=$(awk -F '\t' '$1 == 0 && $3 ~ /^spot run openspot\/new step build=b1 words=./' "$PLACE/calls.tsv" | wc -l | tr -d ' ')
echo "steps: $steps"
[ "$steps" -ge 3 ]
