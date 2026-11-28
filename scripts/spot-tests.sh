#!/bin/sh
set -e
. "$(dirname "$0")/checks.sh"
for spot_folder in $spot_folders; do
  for tests in "$spot_folder"/*.spot/tests/run.sh; do
    [ -f "$tests" ] || continue
    perl -e 'alarm 300; exec @ARGV' sh "$tests" >/dev/null 2>&1 || {
      perl -e 'alarm 300; exec @ARGV' sh "$tests"
      exit 1
    }
  done
done
echo "Spot tests passed."
