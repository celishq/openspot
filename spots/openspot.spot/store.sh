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

# Prints a toast of the last line of a text, such as what a failed `openspot` call said.
toast() {
  printf 'toast=%s\n\n' "$(printf '%s\n' "$1" | tail -n 1)"
}

# Gets spot $1 from the store, and says in a toast that it did, or why it did not.
get() {
  if said=$(openspot store get "$1" 2>&1); then toast "$said"; else toast "$said"; return 1; fi
}

# Publishes spot $1, and says in a toast why it did not. Openspot says itself that it did, and opens Account
# when no key signs it yet.
publish() {
  said=$(openspot store publish "$1" 2>&1 >/dev/null) && return 0
  openspot account --frame | grep -qx 'signedIn=true' || return 0
  toast "$said"
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
      publish:*) publish "${2#publish:}" ;;
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
