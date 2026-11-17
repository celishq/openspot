#!/bin/sh
. "$TASKS/checks.sh"
echo "got: $(answer)"
used calc && [ "$(answer)" = 12 ]
