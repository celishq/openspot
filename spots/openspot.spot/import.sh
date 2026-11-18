#!/bin/sh
# title=Import from Raycast
# icon=square.and.arrow.down
# detail=Bring your script commands
# keywords=raycast, import, script commands
# on=sheet.open
# uses=app,spots,files
. "$OPENSPOT_SH"

# The folder of script commands that the person chose last, kept so the sheet shows it again.
kept="$OPENSPOT_DATA/raycast-folder"

# Prints the rows of a dry run of folder $1: what an import adds, what it already has, and what it skips, each under its title.
rows() {
  openspot import raycast "$1" --dry-run | awk -v folder="$1" '
    /^row=/ { id = substr($0, 5) }
    /^title=/ { title = $0 }
    /^detail=/ { detail = $0 }
    /^outcome=/ { outcome = substr($0, 9) }
    /^file=/ { relative = substr($0, 6); file = "file=" folder "/" relative }
    /^$/ && id != "" {
      if (outcome != "skipped") detail = "detail=" relative
      block = "row=" outcome ":" id "\n" title "\n" detail "\n" file "\n"
      if (outcome == "added") { added = added block "section=To add\nicon=plus.circle\n\n"; count++ }
      else if (outcome == "kept") kept = kept block "section=Already imported\nicon=checkmark.circle\ntone=good\n\n"
      else skipped = skipped block "section=Skipped\nicon=minus.circle\n\n"
      id = ""
    }
    END { printf "count=%d\n\n%s%s%s", count, added, kept, skipped }
  '
}

# Prints the sheet that asks for a folder.
ask() {
  printf 'grid=intro\ngrid=intro\ngrid=intro\ngrid=choose\n\n'
  printf 'text=intro\ntitle=Bring your Raycast script commands\n'
  printf 'detail=Choose the folder that holds them. Each script becomes a spot of your own, and Raycast keeps its copy.\n\n'
  printf 'button=choose\ntitle=Choose Folder…\nlook=strong\nshortcut=return\n'
}

# Prints the sheet of folder $1, with the rows of its dry run.
show() {
  found=$(rows "$1") || exit 1
  count=$(openspot_value count "$found")
  printf 'recents=false\ngrid=summary\ngrid=summary\ngrid=files\n'
  [ "${count:-0}" -gt 0 ] && printf 'grid=import\n'
  printf '\ntext=summary\n'
  if [ "${count:-0}" -gt 0 ]; then
    openspot_kv title "Add $count script$( [ "$count" = 1 ] || echo s) from Raycast"
  else
    openspot_kv title 'Nothing new to add'
  fi
  case "$1" in "$HOME"/*) openspot_kv detail "~${1#"$HOME"}" ;; *) openspot_kv detail "$1" ;; esac
  printf '\nrepeat=files\n'
  [ "${count:-0}" -gt 0 ] && printf '\nbutton=import\ntitle=Import\nlook=strong\nshortcut=cmd+return\n'
  printf '\nbutton=choose\ntitle=Choose Another Folder…\nshortcut=cmd+o\nscope=spot\n'
  printf '\nbutton=open\ntitle=Show in Finder\nclose=false\n\n'
  printf '%s\n' "$found" | sed '1,2d'
}

case "$1" in
  read)
    folder=$(cat "$kept" 2>/dev/null)
    if [ -n "$folder" ] && [ -d "$folder" ]; then show "$folder"; else ask; fi
    ;;
  choose)
    folder=$(openspot folder pick)
    [ -z "$folder" ] || openspot_keep "$kept" "$folder"
    # The picker takes the focus, which hides the panel, so open it again on this sheet.
    openspot spot open openspot/import
    ;;
  import)
    folder=$(cat "$kept" 2>/dev/null)
    [ -n "$folder" ] || exit 0
    done=$(openspot import raycast "$folder") || exit 1
    added=$(printf '%s\n' "$done" | grep -c '^outcome=added$')
    openspot_kv toast "Added $added spot$( [ "$added" = 1 ] || echo s)"
    ;;
  open) open -R "$(value file)" ;;
esac
