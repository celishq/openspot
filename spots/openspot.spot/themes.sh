#!/bin/sh
# title=Themes
# icon=paintpalette
# detail=Change the look
# keywords=theme, look
# on=sheet.open
# uses=app,clipboard
# offers=card
# pages=prompt:*
. "$OPENSPOT_SH"
nl='
'

# The themes, the built-in ones first, with the one in use checked. Return uses a theme. A built-in theme can't change,
# so its rows hide Rename, Move to Trash and Open file. Copy prompt pushes the page `prompt:<name>`, where the person
# describes a look and copies a prompt that hands the theme to their agent.

# Prints the list of themes with the head lines in $1 before it.
list() {
  themes=$(openspot theme list) || exit 1
  printf '%srecents=false\n\nbutton=open\ntitle=Use\nclose=false\n\n' "${1-}"
  printf 'button=duplicate\ntitle=Duplicate\n\nbutton=rename\ntitle=Rename\nform=true\n\n'
  printf 'button=delete\ntitle=Move to Trash\nshortcut=cmd+backspace\nconfirm=Press again to move the theme to the Trash\n\n'
  printf 'button=file\ntitle=Open file\nclose=true\n\nbutton=prompt\ntitle=Copy prompt\n'
  printf '%s\n' "$themes" | awk 'BEGIN { RS = ""; FS = "\n" }
    { delete f
      for (i = 1; i <= NF; i++) { n = index($i, "="); f[substr($i, 1, n - 1)] = substr($i, n + 1) }
      printf "\nrow=%s\ntitle=%s\nicon=paintpalette\n", f["theme"], f["theme"]
      if (f["builtin"] == "true") printf "detail=Built in\nhides=rename\nhides=delete\nhides=file\n"
      if (f["used"] == "true") printf "value=true\n" }'
}

# Prints the page of theme $2 with the words $1 in its field, and the words of its button in $3.
page() {
  printf 'grid=describe describe describe\ngrid=describe describe describe\ngrid=describe describe describe\ngrid=copy copy copy\n\n'
  printf 'field=describe\ntype=multiline\nplaceholder=Describe the look you want for %s\n' "$2"
  openspot_kv value "$1"
  printf '\nbutton=copy\ntitle=%s\nlook=strong\nshortcut=cmd+return\n' "${3:-Copy prompt}"
}

case "$OPENSPOT_PAGE" in
  prompt:*)
    theme=${OPENSPOT_PAGE#prompt:}
    draft="$OPENSPOT_DATA/prompts/$theme.draft"
    # The words of the field: the ones on stdin when the page sends them, or else the draft that a last call kept.
    case "$nl$(openspot_input)" in
      *"${nl}describe="*)
        typed=$(value describe; printf x)
        typed=${typed%x}
        openspot_keep "$draft" "$typed"
        ;;
      *)
        typed=$(cat "$draft" 2>/dev/null; printf x)
        typed=${typed%x}
        ;;
    esac
    case "$1" in
      read | describe) page "$typed" "$theme" ;;
      copy)
        words=$(openspot prompt theme "$theme" "$typed") || exit 1
        printf '%s' "$words" | openspot clipboard copy || exit 1
        rm -f "$draft"
        printf 'toast=Prompt copied. Paste it into your agent.\n'
        page "$typed" "$theme" "✓ Copied"
        printf -- '---\n'
        sleep 1.5
        page "$typed" "$theme"
        ;;
      *)
        echo 'Themes cannot do that.' >&2
        exit 1
        ;;
    esac
    ;;
  *)
    case "$1" in
      read) list ;;
      open) openspot theme use "$2" >/dev/null && list ;;
      duplicate)
        said=$(openspot theme duplicate "$2") || exit 1
        list "toast=$said$nl"
        ;;
      rename)
        if [ -z "$(openspot_input)" ]; then
          printf 'title=Rename %s\n\nfield=name\ntitle=Name\n' "$2"
          openspot_kv value "$2"
          exit 0
        fi
        name=$(value name)
        said=$(openspot theme rename "$2" "$name") || exit 1
        name=${said#"Renamed the theme $2 to "}
        list "select=${name%.}$nl"
        ;;
      delete)
        said=$(openspot theme delete "$2") || exit 1
        list "toast=$said$nl"
        ;;
      file) exec openspot theme open "$2" ;;
      prompt) printf 'push=prompt:%s\npush.title=%s\n' "$2" "$2" ;;
      *)
        echo 'Themes cannot do that.' >&2
        exit 1
        ;;
    esac
    ;;
esac
