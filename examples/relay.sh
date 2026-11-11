#!/bin/sh
# title=Relay
# icon=antenna.radiowaves.left.and.right
# detail=Send a line to another process, and see each line it sends back
# stay=always
# read=panel
. "$OPENSPOT_SH"
port=${RELAY_PORT:-47800}
peer=127.0.0.1:$port

sheet() {
  printf 'end=%s\ngrid=last last last\ngrid=last last last\ngrid=peer peer peer\ngrid=- - -\n' "$call"
  printf 'grid=message message message\ngrid=message message message\ngrid=. . send\n\n'
  printf 'text=last\ntitle=No message yet\ndetail=Listening on 127.0.0.1:%s\n\n' "$port"
  printf 'field=peer\ntitle=To\nvalue=%s\n\n' "$(esc "$peer")"
  printf 'field=message\ntype=multiline\nplaceholder=Hello\n\n'
  printf 'button=send\ntitle=Send\nshortcut=cmd+return\n---\n'
}

listen() {
  while :; do
    nc -l 127.0.0.1 "$port" 2>/dev/null | while IFS= read -r line; do
      printf 'text=last\ntitle=%s\ndetail=From a peer\n\ntoast=%s\n---\n' "$(esc "$line")" "$(esc "$line")"
    done
    sleep 1
  done
}

listen &
listener=$!
trap 'pkill -P "$listener"; kill "$listener"' EXIT
trap 'exit' TERM
while next; do
  [ -z "$stop" ] || continue
  case "$(arg 1)" in
    read) sheet ;;
    send)
      peer=$(value peer)
      if { value message; echo; } | nc -w 1 "${peer%:*}" "${peer##*:}" 2>/dev/null; then
        printf 'toast=Sent\nend=%s\n---\n' "$call"
      else
        printf 'toast=Nothing listens on %s. Start Relay there first.\nend=%s\n---\n' "$(esc "$peer")" "$call"
      fi ;;
    *) printf 'end=%s\n---\n' "$call" ;;
  esac
done
