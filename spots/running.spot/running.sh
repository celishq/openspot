#!/bin/sh
# title=Running spots
# icon=gauge.with.dots.needle.33percent
# detail=What each spot costs
# on=sheet.open
frame=$(openspot spot stats --frame) || exit 1
stats=$(printf '%s\n' "$frame" | awk 'BEGIN { RS = ""; ORS = "\n\n" } /^row=/')
printf 'grid=spots\ngrid.small=top\n\n'
printf '%s\n' "$stats" | awk '
  /^row=/ { n++ }
  n == 1 && /^title=/ { sub(/^title=/, ""); title = $0 }
  n == 1 && /^detail=/ { sub(/^detail=/, ""); detail = $0 }
  END { printf "text=top\ntitle=%s\ndetail=%s\n\n", title, detail }'
printf 'repeat=spots\n\n%s\n' "$stats"
