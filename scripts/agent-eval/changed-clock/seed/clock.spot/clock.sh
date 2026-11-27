#!/bin/sh
case "$1" in
  show)
    printf 'item=tokyo\ntitle=%s\ndetail=Tokyo\n' "$(TZ=Asia/Tokyo date +%H:%M)"
    ;;
esac
