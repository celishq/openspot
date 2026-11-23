#!/bin/sh
. "$TASKS/checks.sh"
wanted=$(ids | grep -c .)
echo "wanted: $wanted; got: $(answer)"
[ "$(answer)" = "$wanted" ]
