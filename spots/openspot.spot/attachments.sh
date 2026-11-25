#!/bin/sh
. "$OPENSPOT_SH"

# The sources of attachments: each spot that comes with Openspot and puts a value in the panel's field, shown or hidden.
# Return hides or shows the chip of the source of the row, and Settings opens its Settings. A hidden source stays on.
#
# Under Access, each app that Openspot reads for a source, and whether macOS lets it. Return on an app not asked yet asks
# for access, on one that is allowed or not allowed opens its pane of System Settings, and on a closed one opens the app.

pane='x-apple.systempreferences:com.apple.preference.security?Privacy_'

# Prints the list of sources, then the access of each reader.
list() {
  spots=$(openspot spot list --core) || exit 1
  access=$(openspot access list) || exit 1
  hidden=$(hidden) || exit 1
  printf 'frame=\nrecents=false\n\nbutton=press\nparent=list\ntitle=Show or hide\nclose=false\n\n'
  printf 'button=settings\nparent=list\ntitle=Settings\nshortcut=cmd+return\n\nitems=list\n'
  printf '%s\n' "$spots" | awk -v hidden=" $hidden " 'BEGIN { RS = ""; FS = "\n" }
    { delete f; source = 0
      for (i = 1; i <= NF; i++) {
        n = index($i, "="); key = substr($i, 1, n - 1); f[key] = substr($i, n + 1)
        if (key == "uses" && f[key] == "attachment") source = 1
      }
      if (!source) next
      shown = index(hidden, " " f["item"] " ") ? "false" : "true"
      printf "\nitem=%s\nparent=list\ntitle=%s\nicon=%s\nvalue=%s\n", f["item"], f["title"], f["icon"], shown
      if (f["detail"] != "") printf "detail=%s\n", f["detail"]
      printf "open.title=%s\n", (shown == "true" ? "Hide" : "Show") }'
  printf '\nbox=access\nparent=list\ntitle=Access\n'
  printf '%s\n' "$access" | awk 'BEGIN { RS = ""; FS = "\n" }
    { delete f
      for (i = 1; i <= NF; i++) { n = index($i, "="); f[substr($i, 1, n - 1)] = substr($i, n + 1) }
      if (f["app"] == "accessibility") { title = "Selected text"; icon = "character.cursor.ibeam" }
      else { title = f["path"]; sub(/.*\//, "", title); sub(/\.app$/, "", title); icon = f["path"] }
      printf "\nitem=access-%s\nparent=access\ntitle=%s\nicon=%s\napp=%s\naccess=%s\nhides=settings\n", f["app"], title, icon, f["app"], f["access"]
      if (f["access"] == "allowed") printf "detail=Allowed\nopen.title=Manage in System Settings\n"
      else if (f["access"] == "denied") printf "detail=Not allowed\nopen.title=Open System Settings\n"
      else if (f["access"] == "unasked") printf "detail=Not asked\nopen.title=Ask for access\n"
      else printf "detail=Open the app to check\nopen.title=Open %s\n", title }'
}

# Prints the id of each hidden source on one line.
hidden() {
  openspot setting list | awk 'BEGIN { RS = ""; FS = "\n" }
    { delete f
      for (i = 1; i <= NF; i++) { n = index($i, "="); f[substr($i, 1, n - 1)] = substr($i, n + 1) }
      if (f["key"] == "attachment" && f["value"] == "false") printf "%s ", f["spot"] }'
}

# Asks for the access of the reader of the pressed row, or opens where the person gives it.
ask() {
  app=$(value item.app)
  case "$(value item.access)" in
    unasked) openspot access ask "$app" >/dev/null ;;
    unknown) open -b "$app" ;;
    *)
      if [ "$app" = accessibility ]; then open "${pane}Accessibility"; else open "${pane}Automation"; fi
      ;;
  esac
}

source=$(value item)
case "$1" in
  show) list ;;
  press)
    case "$source" in
      access-*) ask ;;
      *)
        case " $(hidden) " in
          *" $source "*) openspot setting set --spot "$source" attachment || exit 1 ;;
          *) openspot setting set --spot "$source" attachment false || exit 1 ;;
        esac
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
