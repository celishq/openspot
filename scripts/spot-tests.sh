#!/bin/sh
set -e
for tests in spots/*.spot/tests/run.sh store/*.spot/tests/run.sh examples/*.spot/tests/run.sh; do
  [ -f "$tests" ] || continue
  perl -e 'alarm 300; exec @ARGV' sh "$tests" >/dev/null 2>&1 || {
    perl -e 'alarm 300; exec @ARGV' sh "$tests"
    exit 1
  }
done
echo "Spot tests passed."
