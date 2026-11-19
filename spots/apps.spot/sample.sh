#!/bin/sh
printf 'button=reveal\ntitle=Show in Finder\nshortcut=cmd+return\n\n'
printf 'button=quit\ntitle=Quit\nshortcut=cmd+shift+q\nclose=false\n\n'
printf 'button=uninstall\ntitle=Delete\nshortcut=cmd+backspace\nclose=false\n\n'
for app in Calculator:quit Calendar:true Maps:quit Music:true Notes:true Photos:quit Safari:true 'System Settings:quit'; do
  name=${app%:*}
  path=/System/Applications/$name.app
  [ "$name" = Safari ] && path=/Applications/Safari.app
  printf 'text=%s\ntitle=%s\nicon=%s\n' "$path" "$name" "$path"
  if [ "${app#*:}" = true ]; then printf 'value=true\n'; else printf 'hides=quit\n'; fi
  [ "$name" = Safari ] || printf 'hides=uninstall\n'
  printf '\n'
done
