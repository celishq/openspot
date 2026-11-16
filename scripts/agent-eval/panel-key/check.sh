#!/bin/sh
. "$TASKS/checks.sh"
wanted=$("$OPENSPOT" app status </dev/null | python3 -I -c "
import json, sys
text = sys.stdin.read()
try:
    status = json.loads(text)
    print(status.get(\"panel-key\") or status[\"panelKey\"])
except ValueError:
    print(next(l.split(\"=\", 1)[1] for l in text.splitlines() if l.startswith((\"panelKey=\", \"panel-key=\"))))
")
echo "wanted: $wanted; got: $(answer)"
[ "$(answer)" = "$wanted" ]
