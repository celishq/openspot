#!/bin/sh
# title=New spot
# icon=plus
# detail=Make your own
# on=sheet.open
# uses=clipboard
# edits=spots
. "$OPENSPOT_SH"
folder="${OPENSPOT_SPOTS:-$OPENSPOT_CONFIG/spots}"

# The same sheet edits a spot when Openspot names it in OPENSPOT_EDIT, with a draft of its own for each spot.
edit=${OPENSPOT_EDIT-}
if [ -n "$edit" ]; then
  draft="$OPENSPOT_DATA/edits/$edit.draft"
  copied="$OPENSPOT_DATA/edits/$edit.copied"
  placeholder='Describe what you want to change'
else
  draft="$OPENSPOT_DATA/draft"
  copied="$OPENSPOT_DATA/copied"
  placeholder='Describe what you want to build'
fi
nl='
'

# Prints the sheet with these words in its field, the head lines in $2 before its layout, and the words of its button in $3.
sheet() {
  printf '%s' "$2"
  printf 'grid=describe describe describe\ngrid=describe describe describe\ngrid=describe describe describe\ngrid=copy copy copy\n\n'
  printf 'field=describe\ntype=multiline\nplaceholder=%s\n' "$placeholder"
  openspot_kv value "$1"
  printf '\nbutton=copy\ntitle=%s\nlook=strong\nshortcut=cmd+return\n\n' "${3:-Copy prompt}"
  printf 'button=clear\ntitle=Clear\nscope=spot\n\n'
  [ -z "${OPENSPOT_EDIT_FILE-}" ] || printf 'button=editor\ntitle=Open in editor\nscope=spot\nclose=true\n\n'
  printf 'button=guide\ntitle=Read the guide\nscope=spot\nclose=true\n'
  [ -n "$edit" ] || printf '\nbutton=folder\ntitle=Open spots folder\nscope=spot\nclose=true\n'
}

# Prints the prompt for the agent: to change the spot of OPENSPOT_EDIT, or to build a new one, as the words say.
prompt() {
  if [ -n "$edit" ]; then
    set -- "$edit" ${OPENSPOT_EDIT_FAILURE:+--failure "$OPENSPOT_EDIT_FAILURE"} ${1:+"$1"}
    openspot prompt change "$@"
  elif [ -n "$1" ]; then
    openspot prompt new "$1"
  else
    openspot prompt new
  fi
}

# The words of the field: the ones on stdin when the sheet sends them, or else the draft that a last call kept. A draft that
# was copied is done, so the sheet opens empty.
case "$nl$_openspot_stdin" in
  *"${nl}describe="*)
    typed=$(value describe; printf x)
    typed=${typed%x}
    mkdir -p "${draft%/*}" && printf '%s' "$typed" > "$draft"
    ;;
  *)
    typed=$(cat "$draft" 2>/dev/null; printf x)
    typed=${typed%x}
    if [ -f "$copied" ] && [ "$typed" = "$(cat "$copied")" ]; then
      rm -f "$draft" "$copied"
      typed=
    fi
    ;;
esac

case "$1" in
  read | describe) sheet "$typed" ;;
  copy)
    text=$(printf '%s' "$typed" | awk '{ lines[NR] = $0 } END { s = ""; for (i = 1; i <= NR; i++) s = s (i > 1 ? "\n" : "") lines[i]; sub(/^[ \t\n]+/, "", s); sub(/[ \t\n]+$/, "", s); printf "%s", s }')
    words=$(prompt "$text") || exit 1
    printf '%s' "$words" | openspot clipboard copy || exit 1
    mkdir -p "${copied%/*}" && printf '%s' "$typed" > "$copied"
    sheet "$typed" "toast=Prompt copied. Paste it into your agent.$nl" "✓ Copied"
    printf -- '---\n'
    sleep 1.5
    sheet "$typed"
    ;;
  clear)
    rm -f "$draft" "$copied"
    sheet ""
    ;;
  editor)
    open -t "$OPENSPOT_EDIT_FILE"
    ;;
  guide)
    openspot guide > "$OPENSPOT_DATA/GUIDE.md" && open "$OPENSPOT_DATA/GUIDE.md"
    ;;
  folder)
    mkdir -p "$folder" && open "$folder"
    ;;
  *)
    echo 'New spot cannot do that.' >&2
    exit 1
    ;;
esac
