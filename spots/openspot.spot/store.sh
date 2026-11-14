#!/bin/sh
# title=Store
# icon=bag
# detail=Get spots
# keywords=store, get spots, publish
# on=sheet.open
# uses=spots,account
# offers=card
# offers=search
# offers=window

# Prints the field $2 of the block of spot $1 in the store's list.
field() {
  openspot store list --frame | awk -v id="$1" -v key="$2" 'BEGIN { RS = ""; FS = "\n" }
    { found = 0; value = ""
      for (i = 1; i <= NF; i++) { split($i, kv, "="); if ($i == "spot=" id) found = 1; if (kv[1] == key) value = substr($i, length(key) + 2) }
      if (found) { print value; exit } }'
}

case "$1" in
  read)
    printf 'button=open\ntitle=Get\n\nbutton=publish\ntitle=Publish\nshortcut=cmd+p\n'
    openspot store list --frame | awk 'BEGIN { RS = ""; FS = "\n" }
      { delete f
        for (i = 1; i <= NF; i++) { n = index($i, "="); f[substr($i, 1, n - 1)] = substr($i, n + 1) }
        printf "\nrow=%s\ntitle=%s\nicon=%s\n", f["spot"], f["name"], f["icon"]
        detail = f["detail"]
        if (f["published"] == "current") detail = "Published"
        else if (f["published"] == "changed") detail = "Changes not published"
        else if (f["origin"] == "mine") detail = "Not published"
        if (detail != "") printf "detail=%s\n", detail
        if (f["added"] == "true") printf "value=true\nopen=Show\n"
        if (f["origin"] != "mine" || f["published"] == "current") printf "hides=publish\n" }'
    ;;
  open)
    [ -n "$2" ] || exit 0
    case "$(field "$2" origin):$(field "$2" added)" in
      *:true) exec openspot spot show "$2" ;;
      core:*) openspot setting set --spot "$2" enabled true && printf 'toast=Added %s\n' "$(field "$2" name)" ;;
      store:*) openspot spot add "$(field "$2" path)" >/dev/null && printf 'toast=Added %s\n' "$(field "$2" name)" ;;
    esac
    ;;
  publish)
    [ -n "$2" ] || exit 0
    openspot store publish "$2" >/dev/null
    ;;
  *)
    echo 'Store cannot do that.' >&2
    exit 1
    ;;
esac
