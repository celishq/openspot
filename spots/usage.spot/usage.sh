#!/bin/sh
# title=Usage
# keywords=Running spots, statistics
# icon=gauge.with.dots.needle.33percent
# detail=Use and cost of each spot
# on=sheet.open
# view=chart.swift
# offers=card
# pages=spot:*
# uses=spots,clipboard

here=$(dirname "$0")

# Prints the change of spot $1 since its last version against the versions before it.
change() {
  openspot spot stats --days 14 --spot "$1" --by version | awk -f "$here/stats.awk" -f "$here/change.awk"
}

# Prints the page of spot $1.
page() {
  openspot spot stats --days 14 | awk -v want="$1" -v change="$(change "$1")" -f "$here/stats.awk" -f "$here/page.awk"
}

case "$OPENSPOT_PAGE" in
  spot:*)
    id=${OPENSPOT_PAGE#spot:}
    case "$1" in
      open) exec openspot spot open "$id" ;;
      settings) exec openspot spot settings "$id" ;;
      improve) exec openspot spot edit "$id" ;;
      delete) openspot spot delete "$id" && printf 'pop=true\n' ; exit ;;
    esac
    page "$id"
    exit
    ;;
esac

# A dot pushes the page of its spot. A search that found nothing copies a prompt to build a spot for it.
case "$1" in
  open)
    case "$2" in
      search:*)
        openspot prompt new "A spot for what I search in Openspot as \"${2#search:}\", which finds nothing yet" | openspot clipboard copy || exit 1
        printf 'toast=Prompt copied. Paste it into your agent.\n'
        exit
        ;;
    esac
    ;;
  chart) printf 'push=spot:%s\npush.title=%s\n' "$2" "$(openspot spot stats --days 14 --spot "$2" | sed -n 's/^title=//p' | head -n 1)"; exit ;;
esac

frame=$(openspot spot stats --days 14) || exit 1

# Prints the sheet: the chart, then the rows that list.awk orders.
printf '%s\n' "$frame" | awk -f "$here/stats.awk" -f "$here/list.awk" | sort -t "$(printf '\t')" -k1,1n -k2,2 | {
  printf 'grid=chart\ngrid=chart\ngrid=chart\ngrid=chart\ngrid=spots\ngrid.small=top\nrecents=false\n\n'
  printf 'view=chart\ngrow=false\n\n'
  first=1
  while IFS="$(printf '\t')" read -r _ _ block; do
    printf '%s\n' "$block" | tr '\001' '\n'
    if [ "$first" = 1 ]; then printf 'repeat=spots\n\n'; first=0; fi
  done
}
