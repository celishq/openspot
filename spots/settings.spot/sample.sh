#!/bin/sh
link=x-apple.systempreferences:
panes=/System/Library/ExtensionKit/Extensions
for pane in 'com.apple.wifi-settings-extension:Wi‑Fi:Wi-Fi' 'com.apple.BluetoothSettings:Bluetooth:Bluetooth' 'com.apple.Displays-Settings.extension:Displays:DisplaysExt' \
  'com.apple.Sound-Settings.extension:Sound:Sound' 'com.apple.Notifications-Settings.extension:Notifications:NotificationsSettings' \
  'com.apple.Keyboard-Settings.extension:Keyboard:KeyboardSettings' 'com.apple.Wallpaper-Settings.extension:Wallpaper:Wallpaper'; do
  id=${pane%%:*}
  rest=${pane#*:}
  printf 'item=%s%s#%s\ntitle=%s\ndetail=System Settings\nicon=%s/%s.appex\n\n' "$link" "$id" "${rest%%:*}" "${rest%%:*}" "$panes" "${rest#*:}"
done
printf 'item=%scom.apple.Displays-Settings.extension?ambienceSection#Display Brightness\ntitle=Display Brightness\n' "$link"
printf 'detail=System Settings › Displays\nplace=Displays\nicon=%s/DisplaysExt.appex\n' "$panes"
