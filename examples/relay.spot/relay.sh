#!/bin/sh
. "$OPENSPOT_SH"
port=${RELAY_PORT:-47800}
state=$(mktemp -d "${TMPDIR:-/tmp}/relay.XXXXXX") || exit 1
printf '127.0.0.1:%s' "$port" > "$state/peer"

# Prints the whole sheet, since each frame with a block is the whole picture.
sheet() {
  printf 'frame=\nclass=grid grid-cols-3 gap-part\n\n'
  if [ -s "$state/last" ]; then
    printf 'text=last\nclass=col-span-3 row-span-2 bar:flex\n'
    openspot_kv title "$(cat "$state/last")"
    printf 'detail=From a peer\n\n'
  else
    printf 'text=last\nclass=col-span-3 row-span-2 bar:flex\ntitle=No message yet\ndetail=Listening on 127.0.0.1:%s\n\n' "$port"
  fi
  printf 'field=peer\nclass=col-span-3\ntitle=To\n'
  openspot_kv value "$(cat "$state/peer")"
  printf '\n'
  printf 'box=line\nclass=col-span-3 h-px bg-tile\n\n'
  printf 'field=message\nclass=col-span-3 row-span-2 h-60\ntype=multiline\nplaceholder=Hello\n\n'
  printf 'box=blank-1\n\nbox=blank-2\n\n'
  printf 'button=send\ntitle=Send\nshortcut=cmd+return\nclose=false\n'
}

listen() {
  while :; do
    nc -l 127.0.0.1 "$port" 2>/dev/null | while IFS= read -r line; do
      printf '%s' "$line" > "$state/last.new" && mv "$state/last.new" "$state/last"
      openspot toast "$line"
      # One write, so that the lines of a call never land inside the frame.
      frame=$(sheet)
      printf '%s\n---\n' "$frame"
    done
    sleep 1
  done
}

main() {
  case "$1" in
    show | app.launch) sheet ;;
    send)
      peer=$(value peer)
      printf '%s' "$peer" > "$state/peer.new" && mv "$state/peer.new" "$state/peer"
      if { value message; echo; } | nc -w 1 "${peer%:*}" "${peer##*:}" 2>/dev/null; then
        openspot toast Sent
      else
        openspot toast "Nothing listens on $peer. Start Relay there first."
      fi ;;
  esac
}

listen &
listener=$!
trap 'pkill -P "$listener"; kill "$listener"; rm -rf "$state"' EXIT
trap 'exit' TERM
openspot_serve main "$@"
