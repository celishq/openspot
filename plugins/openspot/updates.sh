#!/bin/sh
# title=Updates
# icon=arrow.triangle.2.circlepath
# on=panel.open
# on=app.update
# uses=update
warned="$OPENSPOT_DATA/updates-warned"
status=$(openspot app status --frame) || exit 1
version= ready= calls=0
while IFS='=' read -r key value; do
  case $key in
    version) version=$value ;;
    update) ready=$value ;;
    calls) calls=$value ;;
  esac
done <<EOF
$status
EOF

# Prints a count of calls, such as 1 call or 2 calls.
calls() {
  if [ "$1" = 1 ]; then echo "1 call"; else echo "$1 calls"; fi
}

# Whether the last press warned of this many running calls.
warned() {
  [ "$calls" -gt 0 ] && [ "$(cat "$warned" 2>/dev/null)" = "$calls" ]
}

case "$1" in
  read)
    if [ -z "$ready" ]; then
      rm -f "$warned"
      printf 'title=Updates\ndetail=%s\ngrid=false\n' "$version"
    elif warned; then
      printf 'title=Restart\ndetail=Stops %s\ngrid=true\n' "$(calls "$calls")"
    else
      printf 'title=Restart\ndetail=Update %s\ngrid=true\n' "$ready"
    fi
    ;;
  open)
    if [ -z "$ready" ]; then
      exec openspot update check
    elif [ "$calls" -eq 0 ] || warned; then
      exec openspot update install
    fi
    printf '%s' "$calls" > "$warned"
    printf 'toast=Restarting stops %s. Press again to restart.\n' "$(calls "$calls")"
    ;;
esac
