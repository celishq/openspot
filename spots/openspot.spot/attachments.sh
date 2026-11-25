#!/bin/sh
. "$OPENSPOT_SH"

# The sources of attachments: each spot that comes with Openspot and puts a value in the panel's field, on or off. Return
# turns the source of the row on or off, and Settings opens the Settings of a source that is on. A source of your own
# spots folder is always on.
#
# The last row opens the Access page of Settings, which shows what macOS lets Openspot read for each source.

# Prints the list of sources, then the row that opens Access in Settings.
list() {
  spots=$(openspot spot list --core) || exit 1
  printf 'frame=\nrecents=false\n\nbutton=press\nparent=list\ntitle=Turn on or off\nclose=false\n\n'
  printf 'button=settings\nparent=list\ntitle=Settings\nshortcut=cmd+return\n\nitems=list\n'
  printf '%s\n' "$spots" | awk 'BEGIN { RS = ""; FS = "\n" }
    { delete f; source = 0
      for (i = 1; i <= NF; i++) {
        n = index($i, "="); key = substr($i, 1, n - 1); f[key] = substr($i, n + 1)
        if (key == "uses" && ("," f[key] ",") ~ /,attachment,/) source = 1
      }
      if (!source) next
      printf "\nitem=%s\nparent=list\ntitle=%s\nicon=%s\nvalue=%s\n", f["item"], f["title"], f["icon"], f["on"]
      if (f["detail"] != "") printf "detail=%s\n", f["detail"]
      if (f["own"] == "true") printf "open.title=Always on\n"
      else if (f["on"] == "true") printf "open.title=Turn off\n"
      else printf "open.title=Turn on\nhides=settings\n" }'
  printf '\nitem=access\nparent=list\ntitle=Access\nicon=lock.shield\ndetail=What macOS lets Openspot read\nopen.title=Open in Settings\nhides=settings\n'
}

# Prints the field $2 of the source $1 in the list of core spots.
field() {
  openspot spot list --core | awk -v item="$1" -v key="$2" 'BEGIN { RS = ""; FS = "\n" }
    $1 == "item=" item { for (i = 1; i <= NF; i++) if (index($i, key "=") == 1) { print substr($i, length(key) + 2); exit } }'
}

source=$(value item)
case "$1" in
  show) list ;;
  press)
    case "$source" in
      access) exec openspot app settings --at access ;;
      *)
        if [ "$(field "$source" own)" = true ]; then
          openspot toast 'This source is in your spots folder, so it is always on.'
        elif [ "$(field "$source" on)" = true ]; then
          openspot setting set --spot "$source" enabled false || exit 1
        else
          openspot setting set --spot "$source" enabled true || exit 1
        fi
        ;;
    esac
    list
    ;;
  settings) exec openspot spot settings "$source" ;;
  *)
    echo 'Attachments cannot do that.' >&2
    exit 1
    ;;
esac
