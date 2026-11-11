#!/bin/sh
# title=Spots
# icon=puzzlepiece.extension
# detail=Turn on
# size=small
# read=sheet

# Prints the state of the app, and fails when it cannot.
status() {
  openspot app status
}

case "$1" in
  read)
    spots=$(openspot spot list --core) || exit 1
    app=$(status) || exit 1
    printf 'recents=false\n'
    printf '\nbutton=open\ntitle=Select\nclose=false\n'
    printf '\nbutton=select-all\ntitle=Select all\nshortcut=cmd+shift+a\nscope=command\n'
    printf '\nbutton=review\ntitle=Review code\n'
    printf '\nrow=new\ntitle=New spot\ndetail=Make your own with AI or a starter\nicon=plus\nhides=review\n'
    printf '%s' "$spots" | jq -r 'def esc: gsub("\\\\"; "\\\\") | gsub("\n"; "\\n");
      .[] | "\nrow=\(.id | esc)\ntitle=\(.name | esc)\nicon=\(.icon | esc)\n"
      + (if .own then "detail=In your plugins folder\n" elif .detail then "detail=\(.detail | esc)\n" else "" end)
      + "value=\(.on)"'
    printf '%s' "$app" | jq -r 'select(.firstLaunch == true and .login != null)
      | "\nrow=open_at_login\ntitle=Open at login\nicon=power\nvalue=\(.login)\nhides=review"'
    ;;
  open)
    case "$2" in
      new)
        exec openspot spot open openspot/new
        ;;
      open_at_login)
        if [ "$(status | jq -r '.login')" = true ]; then exec openspot app login off; else exec openspot app login on; fi
        ;;
    esac
    spots=$(openspot spot list --core) || exit 1
    spot=$(printf '%s' "$spots" | jq -c --arg id "$2" '.[] | select(.id == $id)')
    if [ -z "$spot" ]; then
      echo 'Spots has no such spot.' >&2
      exit 1
    elif [ "$(printf '%s' "$spot" | jq -r '.own')" = true ]; then
      echo 'toast=This spot is a file in your plugins folder.'
    elif [ "$(printf '%s' "$spot" | jq -r '.on')" = true ]; then
      exec openspot spot off "$2"
    else
      exec openspot spot on "$2"
    fi
    ;;
  select-all)
    spots=$(openspot spot list --core) || exit 1
    ids=$(printf '%s' "$spots" | jq -r '.[] | select(.own | not) | .id')
    [ -z "$ids" ] || exec openspot spot on $ids
    ;;
  review)
    [ -z "$2" ] || exec openspot spot review "$2"
    ;;
  *)
    echo 'Spots cannot do that.' >&2
    exit 1
    ;;
esac
