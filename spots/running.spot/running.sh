#!/bin/sh
# title=Running spots
# icon=gauge.with.dots.needle.33percent
# detail=What each spot costs
# on=sheet.open
# preview=sample
# offers=card
if [ "$OPENSPOT_REASON" = spot.preview ]; then
  frame=$(for spot in 'links:Links:412:38:48' 'emoji:Emojis & Symbols:236:21:31' 'cpu:CPU:181:720:24' 'apps:Apps:94:35:13' 'translate:Translate:61:9:90' 'battery:Battery:22:120:4'; do
    printf '%s\n' "$spot" | awk -F: '{ printf "row=%s\ntitle=%s\ndetail=%d ms CPU · %d runs · %d ms each\nruns=%d\ncpu=%.3f\n\n", $1, $2, $3, $4, $5, $4, $3 / 1000 }'
  done)
else
  frame=$(openspot spot stats --frame) || exit 1
fi
stats=$(printf '%s\n' "$frame" | awk 'BEGIN { RS = ""; ORS = "\n\n" } /^row=/')
printf 'grid=spots\ngrid.small=top\n\n'
printf '%s\n' "$stats" | awk '
  /^row=/ { n++ }
  n == 1 && /^title=/ { sub(/^title=/, ""); title = $0 }
  n == 1 && /^detail=/ { sub(/^detail=/, ""); detail = $0 }
  END { printf "text=top\ntitle=%s\ndetail=%s\n\n", title, detail }'
printf 'repeat=spots\n\n%s\n' "$stats"
