#!/bin/sh
# Puts what you copied in the last 2 minutes in the panel's field: files as files, a link as a link, a picture as an
# image file and anything else as text, where Tab offers it to each spot that takes it. Openspot counts the age of a copy
# from the first time it sees it, and reads a long text or a picture only when you hand it on.
case "$1" in
  show) openspot attachment add clipboard --newer 2m ;;
esac
