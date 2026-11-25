#!/bin/sh
. "$OPENSPOT_SH"

# Every row of `openspot setting list` as a result of the panel's search, with its title and the name of its spot. Return
# opens the Settings window on the row.

case "$1" in
  show)
    openspot setting list | awk 'BEGIN { RS = ""; FS = "\n" }
      { delete f
        for (i = 1; i <= NF; i++) { n = index($i, "="); f[substr($i, 1, n - 1)] = substr($i, n + 1) }
        if (f["item"] == "") next
        printf "item=%s\ntitle=%s\ndetail=%s\nplace=%s\nicon=%s\n\n", f["item"], f["title"], f["name"], f["name"], f["icon"] }'
    ;;
  press) exec openspot spot open openspot/settings --at "row/$(value item)" ;;
  *)
    echo 'All settings cannot do that.' >&2
    exit 1
    ;;
esac
