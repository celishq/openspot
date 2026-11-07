#!/bin/sh
# Fails when a test reads the real home or the clipboard, or blocks its thread with a sleep.
if grep -rEn 'homeDirectoryForCurrentUser|NSHomeDirectory|NSPasteboard\.general|Thread\.sleep|usleep\(' app/Tests; then
  echo "A test reads the person's state or blocks with a sleep; see Tests in AGENTS.md." >&2
  exit 1
fi
echo "Tests check passed."
