#!/bin/sh
. "$TASKS/checks.sh"
wanted=$("$OPENSPOT" --config "$OPENSPOT_CONFIG" app status --json </dev/null | python3 -I -c "import json, sys; print(json.load(sys.stdin)['panel-key'])")
echo "wanted: $wanted; got: $(answer)"
[ "$(answer)" = "$wanted" ]
