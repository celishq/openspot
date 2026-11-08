#!/bin/sh
# title=Relay
# icon=antenna.radiowaves.left.and.right
# detail=Send a line to another process, and see each line it sends back
# stay=true
# read=launch
. "$OPENSPOT_SH"
port=${RELAY_PORT:-47800}
peer=127.0.0.1:$port
last="No message yet"

sheet() {
  printf 'grid=last last last\ngrid=last last last\ngrid=peer peer peer\ngrid=- - -\n'
  printf 'grid=message message message\ngrid=message message message\ngrid=. . send\n\n'
  printf 'text=last\ntitle=%s\ndetail=Listening on 127.0.0.1:%s\n\n' "$(esc "$last")" "$port"
  printf 'field=peer\ntitle=To\ntext=%s\n\n' "$(esc "$peer")"
  printf 'field=message\ntype=multiline\nplaceholder=Hello\n\n'
  printf 'button=send\ntitle=Send\nshortcut=cmd+return\n'
  printf '%s\n' ---
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
while IFS= read -r line; do
  case "$line" in
    call=*) call=${line#call=}; name= ;;
    arg=*) [ -n "$name" ] || name=${line#arg=} ;;
    peer=*) peer=${line#peer=} ;;
    message=*) message=${line#message=} ;;
    '')
      case "$name" in
        read) sheet ;;
        send)
          if printf '%s\n' "$message" | nc -w 1 "${peer%:*}" "${peer##*:}" 2>/dev/null; then
            printf 'toast=Sent\nend=%s\n---\n' "$call"
          else
            printf 'toast=Nothing listens on %s. Start Relay there first.\nend=%s\n---\n' "$peer" "$call"
          fi ;;
        *) printf 'end=%s\n---\n' "$call" ;;
      esac
      message= ;;
  esac
done
