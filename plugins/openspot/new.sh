#!/bin/sh
# title=New spot
# icon=plus
# detail=Make your own
# size=small
# read=sheet
folder="${OPENSPOT_PLUGINS:-$OPENSPOT_CONFIG/plugins}"

# Prints a row with an id, a title, a detail and an icon.
row() {
  printf '\nrow=%s\ntitle=%s\ndetail=%s\nicon=%s\n' "$1" "$2" "$3" "$4"
}

# Writes a starter of this kind under the first free name from Untitled, and prints that name, then the path of its file.
starter() {
  name=Untitled
  n=1
  while :; do
    if wrote=$(openspot spot new "$name" --from "$1" 2>&1); then
      printf '%s\n%s\n' "$name" "$(printf '%s' "$wrote" | sed -n 's/^Wrote \(.*\)\. Its ID is .*/\1/p')"
      return 0
    fi
    case "$wrote" in *"already exists"*) ;; *) printf '%s\n' "$wrote" >&2; return 1 ;; esac
    n=$((n + 1))
    name="Untitled $n"
  done
}

case "$1" in
  read)
    printf 'search=script\nrecents=false\n'
    printf '\nbutton=open\ntitle=Choose\n'
    printf '\nbutton=guide\ntitle=Read the guide\nscope=command\nclose=true\n'
    printf '\nbutton=folder\ntitle=Open plugins folder\nscope=command\nclose=true\n'
    row ask "Copy prompt for AI" "${2:-Type what the spot should do}" sparkles
    row button Button "Runs a command when you press it" hand.tap
    row list List "Shows rows to pick from" list.bullet
    row number "Live value" "Shows a value that updates" clock
    row form Form "Asks for words and saves them" square.and.pencil
    ;;
  open)
    case "$2" in
      ask)
        text=$(sed -n 's/^search=//p' | head -1 | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        if [ -z "$text" ]; then
          echo 'Type what the spot should do, then press `⏎`.' >&2
          exit 1
        fi
        openspot prompt new "$text" | LC_ALL=en_US.UTF-8 pbcopy || exit 1
        echo 'toast=Copied a prompt for your agent. Paste it into Claude Code, Codex or another agent.'
        ;;
      button|list|number|form)
        made=$(starter "$2") || exit 1
        open -t "$(printf '%s' "$made" | sed -n 2p)"
        printf 'toast=Made %s. Change the file that opened to make it yours.\n' "$(printf '%s' "$made" | sed -n 1p)"
        ;;
      *)
        echo 'New spot cannot do that.' >&2
        exit 1
        ;;
    esac
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
