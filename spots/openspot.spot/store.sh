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

# Gets spot $1 from the store, and says so in a toast.
get() {
  added=$(openspot store get "$1") && printf 'toast=%s\n\n' "$added"
}

# Prints the gallery: each spot with its id, its name, its step, its origin, its description, its size, and
# whether it has sample data, then each line of its readme after its id.
gallery() {
  printf 'view=gallery\n'
  openspot store list --frame | awk 'BEGIN { RS = ""; FS = "\n" }
    { delete f
      for (i = 1; i <= NF; i++) {
        n = index($i, "="); key = substr($i, 1, n - 1); f[key] = substr($i, n + 1)
        if (key == "readme") printf "readme=%s\t%s\n", f["spot"], f[key]
      }
      sample = f["sample"] == "true" ? "sample" : ""
      printf "value=%s\t%s\t%s\t%s\t%s\t%s\t%s\n", f["spot"], f["name"], f["step"], f["origin"], f["detail"], f["size"], sample }'
}

case "$1" in
  read)
    gallery
    ;;
  gallery)
    case "$2" in
      get:*) get "${2#get:}" ;;
      publish:*) openspot store publish "${2#publish:}" >/dev/null ;;
    esac
    gallery
    ;;
  open)
    [ -n "$2" ] || exit 0
    get "$2" || true
    ;;
  *)
    echo 'Store cannot do that.' >&2
    exit 1
    ;;
esac
