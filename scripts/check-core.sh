#!/bin/sh
# Fails when a file in app/Core imports AppKit or SwiftUI.
set -e
if grep -rEn '^[[:space:]]*import[[:space:]]+(AppKit|SwiftUI)' app/Core; then
  echo "app/Core imports AppKit or SwiftUI; move that code to app/Shell." >&2
  exit 1
fi
echo "Core check passed."
