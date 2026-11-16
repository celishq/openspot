#!/bin/sh
# title=Store
# icon=bag
# detail=Get spots
# keywords=store, get spots
# on=sheet.open
# uses=spots,account
# view=store.swift
# offers=card
# offers=window

# Prints a toast of the last line of a text, such as what a failed `openspot` call said.
toast() {
  printf 'toast=%s\n\n' "$(printf '%s\n' "$1" | tail -n 1)"
}

# Gets spot $1 from the store, and says in a toast that it did, or why it did not.
get() {
  if said=$(openspot store get "$1" 2>&1); then toast "$said"; else toast "$said"; return 1; fi
}

# Prints the gallery: a row for each spot with its id, its name, its step, its origin, its description, its size and
# whether it has sample data, and the readme of the spot that $1 names, a line after its id, when its sheet asks.
gallery() {
  openspot store list --frame | awk -v want="${1-}" 'BEGIN { RS = ""; FS = "\n" }
    { delete f
      for (i = 1; i <= NF; i++) {
        n = index($i, "="); key = substr($i, 1, n - 1); f[key] = substr($i, n + 1)
        if (key == "readme" && f["spot"] == want) readme = readme "readme=" want "\t" f[key] "\n"
      }
      rows = rows "\nrow=" f["spot"] "\ntitle=" f["name"] "\nstep=" (f["step"] == "publish" ? "added" : f["step"]) "\norigin=" f["origin"] "\n"
      if (f["detail"] != "") rows = rows "detail=" f["detail"] "\n"
      rows = rows "size=" f["size"] "\n"
      if (f["sample"] == "true") rows = rows "sample=true\n" }
    END { printf "view=gallery\n"; if (want != "") printf "readme=%s\n%s", want, readme; printf "%s", rows }'
}

case "$1" in
  read)
    gallery
    ;;
  gallery)
    case "$2" in
      get:*) get "${2#get:}" ;;
      readme:*) gallery "${2#readme:}"; exit 0 ;;
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
