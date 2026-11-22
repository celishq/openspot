#!/bin/sh
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

# Prints the sheet with these words in its field, and the words of its button in $2.
sheet() {
  printf 'frame=\nclass=gap-group\n\n'
  printf 'field=describe\ntype=multiline\nplaceholder=%s\n' "$placeholder"
  openspot_kv value "$1"
  printf '\nbutton=copy\ntitle=%s\nclass=bg-accent\nshortcut=cmd+return\nclose=false\n\n' "${2:-Copy prompt}"
  printf 'button=clear\ntitle=Clear\nscope=spot\nclose=false\n\n'
  [ -z "${OPENSPOT_EDIT_FILE-}" ] || printf 'button=editor\ntitle=Open in editor\nscope=spot\n\n'
  printf 'button=guide\ntitle=Read the guide\nscope=spot\n'
  [ -n "$edit" ] || printf '\nbutton=folder\ntitle=Open spots folder\nscope=spot\n'
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

# A search ends with a row that makes a spot of the typed words, and a pick of it copies their prompt.
if [ "$(value event)" = search.text ]; then
  text=$(value event.value | awk '{ sub(/^[ \t]+/, ""); sub(/[ \t]+$/, ""); print }')
  [ -z "$text" ] || openspot_item "$text" 'Make a spot' "$text" plus
  exit 0
fi
if [ "$1" = open ]; then
  words=$(openspot prompt new "$2") || exit 1
  printf '%s' "$words" | openspot clipboard copy || exit 1
  openspot toast 'Prompt copied. Paste it into your agent.'
  exit 0
fi

# The words of the field: the ones on stdin when the sheet sends them, or else the draft that a last call kept. A draft that
# was copied is done, so the sheet opens empty.
case "$nl$(openspot_input)" in
  *"${nl}input.describe="*)
    typed=$(value input.describe; printf x)
    typed=${typed%x}
    mkdir -p "${draft%/*}" && printf '%s' "$typed" > "$draft.$$" && mv "$draft.$$" "$draft"
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
  show | describe) sheet "$typed" ;;
  copy)
    text=$(printf '%s' "$typed" | awk '{ lines[NR] = $0 } END { s = ""; for (i = 1; i <= NR; i++) s = s (i > 1 ? "\n" : "") lines[i]; sub(/^[ \t\n]+/, "", s); sub(/[ \t\n]+$/, "", s); printf "%s", s }')
    words=$(prompt "$text") || exit 1
    printf '%s' "$words" | openspot clipboard copy || exit 1
    mkdir -p "${copied%/*}" && printf '%s' "$typed" > "$copied.$$" && mv "$copied.$$" "$copied"
    openspot toast 'Prompt copied. Paste it into your agent.'
    sheet "$typed" "✓ Copied"
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
