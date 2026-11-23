#!/bin/sh
. "$(dirname "$0")/checks.sh"
need app/Shell
found=$(grep -rnE --include='*.swift' '(NSWindow|NSPanel|NSWindowController)\(|class [A-Za-z]+: (NSWindow|NSPanel|NSWindowController)\b' app/Shell | grep -vE '^app/Shell/(Detached/SpotSheetWindow|Detached/SpotFloatPanel|App/SpotsPanel|App/SpotScreenBackdrop|Toast/ToastPanel|Work/WorkCardPanel|ActionMenu/SpotSubmenuWindow|Mac/SpotScreenPick|Picture/SpotPicture|Sheet/SpotSheetWarmth)\.swift:')
if [ -n "$found" ]; then
  echo "Shell makes a window of its own. Open each app window through SpotSheetWindow.make, so it has the chrome, the glass and the keys of the others:" >&2
  echo "$found" >&2
  exit 1
fi
echo "Windows check passed."
