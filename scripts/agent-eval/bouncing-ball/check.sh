#!/bin/sh
. "$TASKS/checks.sh"
lint || exit 1
found=$(ways)
echo "ways: $found"
printf "%s" "$found" | grep -q "its own view"
