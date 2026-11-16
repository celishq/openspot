#!/bin/sh
. "$TASKS/checks.sh"
wanted=$(plutil -extract CFBundleShortVersionString raw "$(dirname "$OPENSPOT")/../Info.plist")
echo "wanted: $wanted; got: $(answer)"
[ "$(answer)" = "$wanted" ]
