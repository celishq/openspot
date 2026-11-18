#!/bin/sh

# Shows a toast of the last line of a text, such as what a failed `openspot` call said.
toast() {
  openspot toast "$(printf '%s\n' "$1" | tail -n 1)"
}

# Gets spot $1 from the store, and says in a toast that it did, or why it did not.
get() {
  if said=$(openspot store get "$1" 2>&1); then toast "$said"; else toast "$said"; return 1; fi
}

# Asks for a folder and adds it as a store, and says in a toast that it did, or why it did not.
add() {
  folder=$(openspot folder pick) && [ -n "$folder" ] || return 1
  said=$(openspot store add "$folder" 2>&1) || { toast "$said"; return 1; }
  toast "$said"
}

# Removes store $1, and says in a toast why it did not.
remove() {
  said=$(openspot store remove "$1" 2>&1) || toast "$said"
}

# Prints the gallery: a folder line for each store with its path, its name, whether it is found and whether it is built in, an item for
# each spot with its id, its name, its step, its origin, its store, its description, its size and whether it has sample
# data, and the readme of the spot that $1 names, a line after its id, when its sheet asks.
gallery() {
  printf 'frame=\ngrid=gallery\n\nview=gallery\n'
  openspot store folders | awk 'BEGIN { RS = ""; FS = "\n" }
    { delete f
      for (i = 1; i <= NF; i++) { n = index($i, "="); f[substr($i, 1, n - 1)] = substr($i, n + 1) }
      printf "folder=%s\t%s\t%s\t%s\n", f["text"], f["title"], (f["found"] == "true" ? "found" : "missing"), (f["builtin"] == "true" ? "builtin" : "added") }'
  openspot store list | awk -v want="${1-}" 'BEGIN { RS = ""; FS = "\n" }
    { delete f
      for (i = 1; i <= NF; i++) {
        n = index($i, "="); key = substr($i, 1, n - 1); f[key] = substr($i, n + 1)
        if (key == "readme" && f["text"] == want) readme = readme "readme=" want "\t" f[key] "\n"
      }
      rows = rows "\ntext=" f["text"] "\ntitle=" f["title"] "\nstep=" (f["step"] == "publish" ? "added" : f["step"]) "\norigin=" f["origin"] "\n"
      if (f["store"] != "") rows = rows "store=" f["store"] "\n"
      if (f["detail"] != "") rows = rows "detail=" f["detail"] "\n"
      rows = rows "size=" f["size"] "\n"
      if (f["sample"] == "true") rows = rows "sample=true\n" }
    END { if (want != "") printf "readme=%s\n%s", want, readme; printf "%s", rows }'
}

case "$1" in
  show)
    gallery
    ;;
  gallery)
    case "$2" in
      get:*) get "${2#get:}" ;;
      add) add || true ;;
      remove:*) remove "${2#remove:}" ;;
      locate:*) if add; then remove "${2#locate:}"; fi ;;
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
