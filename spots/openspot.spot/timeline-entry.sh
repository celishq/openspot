#!/bin/sh
. "$OPENSPOT_SH"

# The acts on an entry of the timeline that start a program: `use` pastes a text, a picture or a file into the front
# app and opens a link of the web, and `copy` copies it. The Timeline and its rows in the search reach them by a binding.

# Copies the entry of the inputs.
copy() {
  case $(value kind) in
    text)
      file=$(value file)
      if [ -n "$file" ]; then openspot clipboard copy < "$file"; else printf '%s' "$(value text)" | openspot clipboard copy; fi
      ;;
    url) printf '%s' "$(value url)" | openspot clipboard copy ;;
    *) openspot clipboard copy "$(value file)" ;;
  esac
}

case "$1" in
  use)
    if [ "$(value kind)" = url ]; then
      case $(value url) in
        http://* | https://*) exec open -- "$(value url)" ;;
      esac
    fi
    copy || exit 1
    exec openspot clipboard paste
    ;;
  copy) copy ;;
esac
