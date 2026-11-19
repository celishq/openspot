#!/bin/sh
# title=Import from Raycast
# icon=square.and.arrow.down
# detail=Bring your scripts and data
# keywords=raycast, import, script commands, quicklinks, snippets
# on=sheet.open
# drop=folder,rayconfig
# pages=scripts
# pages=export
# uses=app,spots,files
. "$OPENSPOT_SH"

# The folder of script commands and the export file that the person chose, each kept so its page shows it again.
folder_kept="$OPENSPOT_DATA/raycast-scripts"
export_kept="$OPENSPOT_DATA/raycast-export"
# What the scripts page found last, which the hub shows under its row with no new dry run.
scripts_note="$OPENSPOT_DATA/raycast-scripts-note"
# The rows that the last Open of the export found, after the path of the export on the first line. Openspot keeps the opened
# export itself, so an import needs no passphrase again.
preview="$OPENSPOT_DATA/raycast-preview"
# The path of the export that Open is opening now, so that a read in the meantime says so too.
marker="$OPENSPOT_DATA/raycast-opening"
# What the person left out, one per line: scripts by their path in the folder, and kinds of data by their id. Each starts ticked.
scripts_off="$OPENSPOT_DATA/raycast-scripts-off"
export_off="$OPENSPOT_DATA/raycast-export-off"

# Takes line $2 out of file $1 when it is there, or puts it in when it is not.
flip() {
  if grep -qxF -- "$2" "$1" 2>/dev/null; then
    grep -vxF -- "$2" "$1" | openspot_keep "$1"
  else
    { cat "$1" 2>/dev/null; printf '%s\n' "$2"; } | openspot_keep "$1"
  fi
}

# Prints a --skip and a line of file $1, for each line of it.
skips() {
  [ -f "$1" ] || return 0
  while IFS= read -r line; do [ -n "$line" ] && printf -- '--skip\n%s\n' "$line"; done < "$1"
}

# Prints a path with the home folder as ~.
short() {
  case "$1" in "$HOME"/*) printf '~%s' "${1#"$HOME"}" ;; *) printf '%s' "$1" ;; esac
}

# Prints the rows of a dry run of folder $1: what an import adds, what it already has, and what it skips, each under its title.
script_rows() {
  openspot import raycast "$1" --dry-run | OFF="$(cat "$scripts_off" 2>/dev/null)" awk -v folder="$1" '
    BEGIN { n = split(ENVIRON["OFF"], lines, "\n"); for (i = 1; i <= n; i++) left[lines[i]] = 1 }
    /^row=/ { id = substr($0, 5) }
    /^title=/ { title = $0 }
    /^detail=/ { detail = $0 }
    /^outcome=/ { outcome = substr($0, 9) }
    /^file=/ { relative = substr($0, 6); file = "file=" folder "/" relative }
    /^$/ && id != "" {
      if (outcome != "skipped") detail = "detail=" relative
      block = "row=" outcome ":" id "\n" title "\n" detail "\n" file "\npath=" relative "\n"
      if (outcome == "added") { added_rows[++count] = block; ticked[count] = !(relative in left); if (ticked[count]) chosen++ }
      else if (outcome == "kept") kept = kept block "section=Already imported\nicon=checkmark.circle\ntone=good\n\n"
      else skipped = skipped block "section=Skipped\nicon=minus.circle\n\n"
      id = ""
    }
    END {
      for (i = 1; i <= count; i++) added = added added_rows[i] "section=To add · " chosen + 0 " of " count "\nvalue=" (ticked[i] ? "true" : "false") "\nicon=terminal\n\n"
      printf "count=%d\n\n%s%s%s", chosen, added, kept, skipped
    }
  '
}

# Prints the rows of the kinds of data that the run in $1 found: what it adds, or with $2 what it added, and what it skips.
data_rows() {
  printf '%s\n\n' "$1" | awk -v done="$2" '
    /^row=/ { id = substr($0, 5) }
    /^title=/ { title = $0 }
    /^detail=/ { detail = $0 }
    /^outcome=/ { outcome = substr($0, 9) }
    /^$/ && id != "" {
      icon = id == "links" ? "link" : id == "snippets" ? "text.quote" : "minus.circle"
      if (outcome == "added" && done != "") added = added "row=done:" id "\n" title "\n" detail "\nsection=Imported\nicon=checkmark.circle\ntone=good\npush.spot=" id "\n\n"
      else if (outcome == "added") { added = added "row=added:" id "\n" title "\n" detail "\nsection=To add\nicon=" icon "\n\n"; count++ }
      else skipped = skipped "row=skipped:" id "\n" title "\n" detail "\nsection=Not supported yet\nicon=minus.circle\n\n"
      id = ""
    }
    END { printf "count=%d\n\n%s%s", count, added, skipped }
  '
}

# Adds a tick to each kind of data to add in the rows on stdin, off for the kinds left out, and puts the count of the ticked ones
# on the first line.
ticked() {
  OFF="$(cat "$export_off" 2>/dev/null)" awk '
    BEGIN { n = split(ENVIRON["OFF"], lines, "\n"); for (i = 1; i <= n; i++) left[lines[i]] = 1 }
    /^count=/ { next }
    /^row=added:/ { kind = substr($0, 11); on = !(kind in left); if (on) chosen++; out = out $0 "\nvalue=" (on ? "true" : "false") "\n"; next }
    { out = out $0 "\n" }
    END { printf "count=%d\n%s", chosen, out }
  '
}

# Says whether export $1 is opening now. A mark older than a minute is from an Open that was stopped.
is_opening() {
  [ -n "$(find "$marker" -mmin -1 2>/dev/null)" ] && [ "$(cat "$marker")" = "$1" ]
}

# Prints the rows that the last Open of export $1 found, or nothing.
kept_preview() {
  [ -f "$preview" ] && [ "$(head -n 1 "$preview")" = "$1" ] && sed '1d' "$preview"
}

# Keeps the rows or the failure of export $1.
keep_preview() {
  printf '%s\n%s\n' "$1" "$2" | openspot_keep "$preview"
}

# Opens export $1 with the passphrase of the field, and keeps the rows of its dry run, or its failure.
open_export() {
  found=$(value passphrase | openspot import rayconfig "$1" --dry-run 2>&1) || found="failure=$(printf '%s\n' "$found" | tail -n 1)"
  case "$found" in failure=*) ;; *) found=$(data_rows "$found") ;; esac
  keep_preview "$1" "$found"
}

# Prints the first sheet: a row for each source, which opens its own page.
hub() {
  printf 'recents=false\nsearch=off\n\nrow=scripts\ntitle=Script Commands\nicon=terminal\npush=scripts\npush.title=Script Commands\n'
  folder=$(cat "$folder_kept" 2>/dev/null)
  if [ -z "$folder" ]; then
    printf 'detail=Choose the folder of your scripts\n'
  elif [ ! -d "$folder" ]; then
    openspot_kv detail "Can't find ${folder##*/}"
    printf 'tone=warn\n'
  else
    openspot_kv detail "$(cat "$scripts_note" 2>/dev/null)"
  fi
  printf '\nrow=export\ntitle=Settings & Data\nicon=gearshape.2\npush=export\npush.title=Settings & Data\n'
  file=$(cat "$export_kept" 2>/dev/null)
  found=$(kept_preview "$file")
  if [ -z "$file" ]; then
    printf 'detail=Quicklinks and snippets from a Raycast export\n'
  elif [ ! -f "$file" ]; then
    printf "detail=Can't find the export\ntone=warn\n"
  elif printf '%s\n' "$found" | grep -q '^row=done:'; then
    printf 'detail=Imported\n'
  elif printf '%s\n' "$found" | grep -q '^row=added:'; then
    printf 'detail=Ready to import\n'
  else
    printf 'detail=Enter the passphrase to open it\n'
  fi
}

# Prints the page that asks to choose again, because the folder or the export at $1 is gone.
gone() {
  printf 'recents=false\nsearch=off\ngrid=gone\ngrid=hint\ngrid=hint\ngrid=choose\n\ntext=gone\ntone=bad\n'
  openspot_kv title "$2"
  printf '\ntext=hint\n'
  openspot_kv title "$(short "$1")"
  openspot_kv detail "$3"
  printf '\nbutton=choose\n'
  openspot_kv title "$4"
  printf 'look=strong\nshortcut=return\n'
}

# Prints the row of the chosen folder or file $1, pinned on top. Return on it chooses another.
source_row() {
  printf '\nrow=source\npin=top\nopen=Change\nclose=false\n'
  openspot_kv title "${1##*/}"
  openspot_kv detail "$(short "${1%/*}")"
  openspot_kv icon "$1"
}

# Prints the page of the script commands folder.
scripts_page() {
  folder=$(cat "$folder_kept" 2>/dev/null)
  if [ -z "$folder" ]; then
    printf 'recents=false\nsearch=off\ngrid=where\ngrid=where\ngrid=choose\n\n'
    printf 'text=where\ntitle=Choose your script commands folder\n'
    printf 'detail=Raycast lists it in Settings → Extensions → Script Commands. Each script becomes a spot, and Raycast keeps its copy.\n\n'
    printf 'button=choose\ntitle=Choose Folder…\nlook=strong\nshortcut=return\n'
    return
  fi
  if [ ! -d "$folder" ]; then
    gone "$folder" "Can't find this folder" "It moved or was deleted. Choose it again, or choose another folder." "Choose Folder…"
    return
  fi
  found=$(script_rows "$folder") || exit 1
  count=$(openspot_value count "$found")
  if printf '%s\n' "$found" | grep -q '^row=added:'; then
    openspot_keep "$scripts_note" "$count to add from ${folder##*/}"
  else
    openspot_keep "$scripts_note" "All imported from ${folder##*/}"
  fi
  printf 'recents=false\ngrid=files\n'
  [ "${count:-0}" -gt 0 ] && printf 'grid=import\n'
  printf '\nrepeat=files\n\nbutton=open\ntitle=Select\nclose=false\n'
  [ "${count:-0}" -gt 0 ] && printf '\nbutton=import\ntitle=Import\nlook=strong\nshortcut=cmd+return\n'
  printf '\nbutton=choose\ntitle=Change Folder\nshortcut=cmd+o\nscope=spot\n'
  source_row "$folder"
  printf '\n'
  printf '%s\n' "$found" | sed '1,2d'
}

# Prints the export page that asks for the passphrase of export $1. With $2 "opening" its button says so, and with a failure
# a red line under the field says what went wrong.
locked_page() {
  failure=$2
  printf 'recents=false\nsearch=off\ngrid=file\ngrid=passphrase\n'
  case "$failure" in
    '' | opening) ;;
    Wrong* | Enter*) printf 'grid=failure\n' ;;
    *) printf 'grid=failure\ngrid=hint\n' ;;
  esac
  printf 'grid=unlock\n\ntext=file\nicon=doc\n'
  openspot_kv title "${1##*/}"
  openspot_kv detail "$(short "${1%/*}")"
  printf '\nfield=passphrase\ntitle=Passphrase\ntype=secret\nplaceholder=Passphrase from Raycast → Settings → Advanced\ngrow=false\n'
  openspot_kv value "$(value passphrase)"
  case "$failure" in
    '' | opening) ;;
    *)
      printf '\ntext=failure\ntone=bad\n'
      openspot_kv title "${failure%%. *}"
      case "$failure" in
        Wrong* | Enter*) ;;
        *) printf '\ntext=hint\n'; openspot_kv title "${failure#*. }" ;;
      esac
      ;;
  esac
  case "$failure" in
    opening) printf '\nbutton=unlock\ntitle=Opening…\nlook=strong\nshortcut=return\n' ;;
    *) printf '\nbutton=unlock\ntitle=Open\nlook=strong\nshortcut=return\n' ;;
  esac
  printf '\nbutton=choose\ntitle=Change File\nshortcut=cmd+o\nscope=spot\n'
}

# Prints the page of the Raycast export.
export_page() {
  file=$(cat "$export_kept" 2>/dev/null)
  if [ -z "$file" ]; then
    printf 'recents=false\nsearch=off\ngrid=where\ngrid=where\ngrid=choose\n\n'
    printf 'text=where\ntitle=Export your data from Raycast\n'
    printf 'detail=In Raycast, run Export Settings & Data, or go to Settings → Advanced and click Export. Raycast saves a .rayconfig file.\n\n'
    printf 'button=choose\ntitle=Choose Export File…\nlook=strong\nshortcut=return\n'
    return
  fi
  if [ ! -f "$file" ]; then
    gone "$file" "Can't find this export" "It moved or was deleted. Choose it again, or export again from Raycast." "Choose Export File…"
    return
  fi
  if is_opening "$file"; then
    locked_page "$file" opening
    return
  fi
  found=$(kept_preview "$file")
  failure=$(openspot_value failure "$found")
  if [ -n "$failure" ] || [ -z "$found" ]; then
    locked_page "$file" "$failure"
    return
  fi
  found=$(printf '%s\n' "$found" | ticked)
  count=$(openspot_value count "$found")
  printf 'recents=false\nsearch=off\ngrid=kinds\n'
  [ "${count:-0}" -gt 0 ] && printf 'grid=import\n'
  printf '\nrepeat=kinds\n\nbutton=open\ntitle=Select\nclose=false\n'
  [ "${count:-0}" -gt 0 ] && printf '\nbutton=import\ntitle=Import\nlook=strong\nshortcut=cmd+return\n'
  printf '\nbutton=choose\ntitle=Change File\nshortcut=cmd+o\nscope=spot\n'
  source_row "$file"
  printf '\n'
  printf '%s\n' "$found" | sed '1d'
}

case "$1" in
  read)
    case "${OPENSPOT_PAGE-}" in
      scripts) scripts_page ;;
      export) export_page ;;
      *) hub ;;
    esac
    ;;
  choose)
    # The chooser drops the folder or the file on this spot, which comes back as a drop.
    openspot spot choose openspot/import
    ;;
  drop)
    if [ -d "$2" ]; then
      openspot_keep "$folder_kept" "$2"
      page=scripts title="Script Commands"
    else
      openspot_keep "$export_kept" "$2"
      page=export title="Settings & Data"
    fi
    # The chooser takes the focus, which hides the panel, so open it again on the page of what was chosen.
    openspot spot open openspot/import
    openspot spot push openspot/import "$page" --title "$title"
    ;;
  passphrase)
    # A head alone changes nothing on the sheet, so no read comes to write over what is still being typed.
    printf 'recents=false\n'
    ;;
  unlock)
    file=$(cat "$export_kept" 2>/dev/null)
    [ -f "$file" ] || exit 0
    trap 'rm -f "$marker"' EXIT
    trap 'exit 143' TERM INT
    openspot_keep "$marker" "$file"
    locked_page "$file" opening
    printf -- '---\n'
    open_export "$file"
    rm -f "$marker"
    export_page
    ;;
  import)
    if [ "${OPENSPOT_PAGE-}" = export ]; then
      file=$(cat "$export_kept" 2>/dev/null)
      [ -f "$file" ] || { echo "Choose the export first." >&2; exit 1; }
      old_ifs=$IFS
      IFS='
'
      set -- $(skips "$export_off")
      IFS=$old_ifs
      done=$(openspot import rayconfig "$file" "$@" </dev/null 2>&1) || {
        keep_preview "$file" "failure=$(printf '%s\n' "$done" | tail -n 1)"
        exit 0
      }
      keep_preview "$file" "$(data_rows "$done" imported)"
      said=$(printf '%s\n' "$done" | awk '/^detail=/ { detail = substr($0, 8) } /^outcome=added$/ { printf "%s%s", sep, detail; sep = " and " }')
      openspot_kv toast "${said:-Nothing new to import}."
      exit 0
    fi
    folder=$(cat "$folder_kept" 2>/dev/null)
    [ -d "$folder" ] || { echo "Choose the folder first." >&2; exit 1; }
    old_ifs=$IFS
    IFS='
'
    set -- $(skips "$scripts_off")
    IFS=$old_ifs
    done=$(openspot import raycast "$folder" "$@") || exit 1
    added=$(printf '%s\n' "$done" | grep -c '^outcome=added$')
    case "$added" in
      0) openspot_kv toast "Nothing new to import." ;;
      1) openspot_kv toast "Added 1 spot. Find it on the grid." ;;
      *) openspot_kv toast "Added $added spots. Find them on the grid." ;;
    esac
    ;;
  open)
    case "$2" in
      added:*)
        if [ "${OPENSPOT_PAGE-}" = export ]; then
          flip "$export_off" "${2#added:}"
        else
          flip "$scripts_off" "$(value path)"
        fi
        ;;
      source) openspot spot choose openspot/import ;;
    esac
    ;;
esac
