#!/bin/sh
# title=Relay
# icon=antenna.radiowaves.left.and.right
# detail=Send a line to another process, and see each line it sends back
# mode=always
# read=panel
. "$OPENSPOT_SH"
port=${RELAY_PORT:-47800}
state=$(mktemp -d "${TMPDIR:-/tmp}/relay.XXXXXX") || exit 1
printf '127.0.0.1:%s' "$port" > "$state/peer"

# Prints the whole sheet, with a line of head first when it is given, since each frame with a block is the whole picture.
sheet() {
  [ -z "${1-}" ] || printf '%s\n' "$1"
  printf 'grid=last last last\ngrid=last last last\ngrid=peer peer peer\ngrid=- - -\n'
  printf 'grid=message message message\ngrid=message message message\ngrid=. . send\n\n'
  if [ -s "$state/last" ]; then
    printf 'text=last\ntitle=%s\ndetail=From a peer\n\n' "$(esc "$(cat "$state/last")")"
  else
    printf 'text=last\ntitle=No message yet\ndetail=Listening on 127.0.0.1:%s\n\n' "$port"
  fi
  printf 'field=peer\ntitle=To\nvalue=%s\n\n' "$(esc "$(cat "$state/peer")")"
  printf 'field=message\ntype=multiline\nplaceholder=Hello\n\n'
  printf 'button=send\ntitle=Send\nshortcut=cmd+return\n'
}

listen() {
  while :; do
    nc -l 127.0.0.1 "$port" 2>/dev/null | while IFS= read -r line; do
      printf '%s' "$line" > "$state/last.new" && mv "$state/last.new" "$state/last"
      sheet "toast=$(esc "$line")"
      printf -- '---\n'
    done
    sleep 1
  done
}

main() {
  case "$1" in
    read) sheet ;;
    send)
      peer=$(value peer)
      printf '%s' "$peer" > "$state/peer.new" && mv "$state/peer.new" "$state/peer"
      if { value message; echo; } | nc -w 1 "${peer%:*}" "${peer##*:}" 2>/dev/null; then
        printf 'toast=Sent\n'
      else
        printf 'toast=Nothing listens on %s. Start Relay there first.\n' "$(esc "$peer")"
      fi ;;
  esac
}

listen &
listener=$!
trap 'pkill -P "$listener"; kill "$listener"; rm -rf "$state"' EXIT
trap 'exit' TERM
openspot_serve main "$@"
