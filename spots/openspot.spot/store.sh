#!/bin/sh
# title=Store
# icon=bag
# detail=Get spots
# keywords=store, get spots, publish
# on=sheet.open
# uses=spots,account
# view=store.swift
# offers=card
# offers=window

# Prints the field $2 of the block of spot $1 in the store's list.
field() {
  openspot store list --frame | awk -v id="$1" -v key="$2" 'BEGIN { RS = ""; FS = "\n" }
    { found = 0; value = ""
      for (i = 1; i <= NF; i++) { n = index($i, "="); if ($i == "spot=" id) found = 1; if (substr($i, 1, n - 1) == key) value = substr($i, n + 1) }
      if (found) { print value; exit } }'
}

# Gets spot $1: turns on a core spot or one of your own that is off, or adds a spot that the store holds.
get() {
  case "$(field "$1" origin)" in
    core | mine) openspot setting set --spot "$1" enabled true ;;
    store) openspot spot add "$(field "$1" path)" >/dev/null ;;
    *) return 0 ;;
  esac && printf 'toast=Added %s\n\n' "$(field "$1" name)"
}

# Prints the gallery: each spot with its id, its name and what its button does.
gallery() {
  printf 'view=gallery\n'
  openspot store list --frame | awk 'BEGIN { RS = ""; FS = "\n" }
    { delete f
      for (i = 1; i <= NF; i++) { n = index($i, "="); f[substr($i, 1, n - 1)] = substr($i, n + 1) }
      state = f["added"] == "true" ? "added" : "get"
      if (f["origin"] == "mine" && f["added"] == "true" && f["published"] != "current") state = "publish"
      printf "value=%s\t%s\t%s\n", f["spot"], f["name"], state }'
}

case "$1" in
  read) gallery ;;
  gallery)
    case "$2" in
      get:*) get "${2#get:}" ;;
      publish:*) openspot store publish "${2#publish:}" >/dev/null ;;
    esac
    gallery
    ;;
  open)
    [ -n "$2" ] || exit 0
    get "$2"
    ;;
  *)
    echo 'Store cannot do that.' >&2
    exit 1
    ;;
esac
