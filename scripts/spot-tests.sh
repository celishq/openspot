#!/bin/sh
set -e
for tests in spots/*.spot/tests/run.sh examples/*.spot/tests/run.sh; do
  [ -f "$tests" ] || continue
  sh "$tests" >/dev/null 2>&1 || {
    sh "$tests"
    exit 1
  }
done
echo "Spot tests passed."
