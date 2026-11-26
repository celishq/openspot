#!/bin/sh
. "$OPENSPOT_SH"

# The sources of attachments: each spot that comes with Openspot and puts a value in the panel's field, shown or hidden.
# Return hides or shows the chip of the source of the row, and Settings opens its Settings. A hidden source stays on.
# Access opens Openspot's Settings at what macOS lets Openspot read.

# Prints the list of sources, then the Access row.
list() {
  spots=$(openspot spot list --core) || exit 1
  hidden=$(hidden) || exit 1
  printf 'frame=\nrecents=false\n\nbutton=press\nparent=list\ntitle=Show or hide\nclose=false\n\n'
  printf 'button=settings\nparent=list\ntitle=Settings\nshortcut=cmd+return\n\nitems=list\n'
  printf '%s\n' "$spots" | awk -v hidden=" $hidden " 'BEGIN { RS = ""; FS = "\n" }
    { delete f; source = 0
      for (i = 1; i <= NF; i++) {
        n = index($i, "="); key = substr($i, 1, n - 1); f[key] = substr($i, n + 1)
        if (key == "uses" && index("," f[key] ",", ",attachment,")) source = 1
      }
      if (!source) next
      shown = index(hidden, " " f["item"] " ") ? "false" : "true"
      printf "\nitem=%s\nparent=list\ntitle=%s\nicon=%s\nvalue=%s\n", f["item"], f["title"], f["icon"], shown
      if (f["detail"] != "") printf "detail=%s\n", f["detail"]
      printf "open.title=%s\n", (shown == "true" ? "Hide" : "Show") }'
  printf '\nitem=access\nparent=list\ntitle=Access\nicon=lock.shield\ndetail=What macOS lets Openspot read\nopen.title=Open in Settings\nhides=settings\n'
}

# Prints the id of each hidden source on one line.
hidden() {
  for source in $(printf "%s\n" "${spots:-$(openspot spot list --core)}" | awk 'BEGIN { RS = ""; FS = "\n" }
    { for (i = 1; i <= NF; i++) { if (index($i, "item=") == 1) item = substr($i, 6); if (index($i, "uses=") == 1 && index("," substr($i, 6) ",", ",attachment,")) print item } }'); do
    [ "$(openspot setting get --spot "$source" attachment)" = false ] && printf '%s ' "$source"
  done
  return 0
}

source=$(value item)
case "$1" in
  show) list ;;
  press)
    case "$source" in
      access) exec openspot app settings --at access ;;
      *)
        case " $(hidden) " in
          *" $source "*) openspot setting set --spot "$source" attachment || exit 1 ;;
          *) openspot setting set --spot "$source" attachment false || exit 1 ;;
        esac
        ;;
    esac
    list
    ;;
  settings) exec openspot app settings --at "spot/$source" ;;
  *)
    echo 'Attachments cannot do that.' >&2
    exit 1
    ;;
esac
