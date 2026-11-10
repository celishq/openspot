#!/bin/sh
# title=Calendars for Agenda
# icon=checklist
# detail=The calendars and lists that Agenda shows
# read=sheet
hidden=$(openspot setting get hidden </dev/null)

# Prints the rows of a list of calendars or of lists, with the kind before the account, and a checkmark on each that Agenda
# shows, as Spots marks the spots that are on.
rows() {
  printf '%s\n' "$2" | awk -v hidden=" $hidden " -v kind="$1" -v icon="$3" 'BEGIN { RS = ""; FS = "\n" }
    /^row=./ {
      for (i = 1; i <= NF; i++) print ($i ~ /^detail=/ ? "detail=" kind " · " substr($i, 8) : $i)
      printf "icon=%s\non=%s\n\n", icon, index(hidden, " " substr($1, 5) " ") ? "false" : "true"
    }'
}

case "$1" in
  read)
    printf 'recents=false\n\nbutton=open\ntitle=Select\nclose=false\n\nbutton=all\ntitle=Select all\nshortcut=cmd+shift+a\nscope=command\n\n'
    calendars=$(openspot calendar calendars </dev/null) || { printf '%s\n' "$calendars"; exit 1; }
    lists=$(openspot reminders lists </dev/null) || { printf '%s\n' "$lists"; exit 1; }
    [ "$calendars" != status=unasked ] || printf 'row=allow-calendar\ntitle=Allow Calendar\ndetail=List your calendars here\nicon=calendar\n\n'
    [ "$lists" != status=unasked ] || printf 'row=allow-reminders\ntitle=Allow Reminders\ndetail=List your reminders here\nicon=checklist\n\n'
    rows Calendar "$calendars" calendar
    rows Reminders "$lists" list.bullet
    ;;
  all) openspot setting set hidden </dev/null ;;
  open)
    case "$2" in
      allow-calendar) out=$(openspot calendar calendars </dev/null) || { printf '%s\n' "$out" | grep '^link='; exit 1; }; exit 0 ;;
      allow-reminders) out=$(openspot reminders lists </dev/null) || { printf '%s\n' "$out" | grep '^link='; exit 1; }; exit 0 ;;
    esac
    next=""
    found=""
    for id in $hidden; do
      if [ "$id" = "$2" ]; then found=1; else next="$next $id"; fi
    done
    [ -n "$found" ] || next="$next $2"
    next=${next# }
    if [ -n "$next" ]; then
      openspot setting set hidden "$next" </dev/null
    else
      openspot setting set hidden </dev/null
    fi
    ;;
esac
