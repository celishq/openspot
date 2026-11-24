#!/bin/sh
. "$OPENSPOT_SH"
nl='
'

# The themes, the built-in ones first, with the one in use checked. Return uses a theme. A built-in theme can't change,
# so its rows hide Rename, Move to Trash and Open file. Copy prompt pushes the page `prompt:<name>`, where the person
# describes a look and copies a prompt that hands the theme to their agent.

# Prints the list of themes.
list() {
  themes=$(openspot theme list) || exit 1
  printf 'frame=\nrecents=false\n\nbutton=press\ntitle=Use\nclose=false\n\n'
  printf 'button=duplicate\ntitle=Duplicate\nclose=false\n\nbutton=rename\ntitle=Rename\nclose=false\n\n'
  printf 'button=delete\ntitle=Move to Trash\nshortcut=cmd+backspace\nconfirm=Press again to move the theme to the Trash\nclose=false\n\n'
  printf 'button=file\ntitle=Open file\n\nbutton=prompt\ntitle=Copy prompt\nclose=false\n'
  printf '%s\n' "$themes" | awk 'BEGIN { RS = ""; FS = "\n" }
    { delete f
      for (i = 1; i <= NF; i++) { n = index($i, "="); f[substr($i, 1, n - 1)] = substr($i, n + 1) }
      printf "\nitem=%s\ntitle=%s\nicon=paintpalette\n", f["item"], f["item"]
      if (f["builtin"] == "true") printf "detail=Built in\nhides=rename\nhides=delete\nhides=file\n"
      if (f["used"] == "true") printf "value=true\n" }'
}

# Prints the page of theme $2 with the words $1 in its field, and the words of its button in $3.
page() {
  printf 'frame=\nclass=gap-group\n\n'
  printf 'field=describe\nclass=grow\ntype=multiline\nplaceholder=Describe the look you want for %s\n' "$2"
  openspot_kv value "$1"
  printf '\nbutton=copy\ntitle=%s\nclass=bg-accent\nshortcut=cmd+return\nclose=false\n' "${3:-Copy prompt}"
}

route=$(value route)
case "$route" in
  prompt:*)
    theme=${route#prompt:}
    draft="$OPENSPOT_DATA/prompts/$theme.draft"
    # The words of the field: the ones on stdin when the page sends them, or else the draft that a last call kept.
    case "$nl$(openspot_input)" in
      *"${nl}input.describe="*)
        typed=$(value input.describe; printf x)
        typed=${typed%x}
        openspot_keep "$draft" "$typed"
        ;;
      *)
        typed=$(cat "$draft" 2>/dev/null; printf x)
        typed=${typed%x}
        ;;
    esac
    case "$1" in
      show | describe) page "$typed" "$theme" ;;
      copy)
        words=$(openspot prompt theme "$theme" "$typed") || exit 1
        printf '%s' "$words" | openspot clipboard copy || exit 1
        rm -f "$draft"
        openspot toast 'Prompt copied. Paste it into your agent.'
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
    theme=$(value item)
    case "$1" in
      show) list ;;
      press) openspot theme use "$theme" >/dev/null && list ;;
      duplicate)
        said=$(openspot theme duplicate "$theme") || exit 1
        openspot toast "$said"
        list
        ;;
      rename)
        if [ -z "$(value input.name)" ]; then
          printf 'frame=\ntype=form\nclass=gap-part\ntitle=Rename %s\n\nfield=name\ntitle=Name\n' "$theme"
          openspot_kv value "$theme"
          exit 0
        fi
        name=$(value input.name)
        said=$(openspot theme rename "$theme" "$name") || exit 1
        name=${said#"Renamed the theme $theme to "}
        openspot select "${name%.}"
        list
        ;;
      delete)
        said=$(openspot theme delete "$theme") || exit 1
        openspot toast "$said"
        list
        ;;
      file) exec openspot theme open "$theme" ;;
      prompt) openspot route push "prompt:$theme" --title "$theme" ;;
      *)
        echo 'Themes cannot do that.' >&2
        exit 1
        ;;
    esac
    ;;
esac
