#!/bin/sh
warned="$OPENSPOT_DATA/updates-warned"
status=$(openspot app status) || exit 1
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
  show)
    if [ -z "$ready" ]; then
      rm -f "$warned"
      printf 'frame=\ntitle=Updates\ndetail=%s\nshown=false\n' "$version"
    elif warned; then
      printf 'frame=\ntitle=Restart\ndetail=Stops %s\nshown=true\n' "$(calls "$calls")"
    else
      printf 'frame=\ntitle=Restart\ndetail=Update %s\nshown=true\n' "$ready"
    fi
    ;;
  update)
    if [ -z "$ready" ]; then
      exec openspot update check
    elif [ "$calls" -eq 0 ] || warned; then
      exec openspot update install
    fi
    printf '%s' "$calls" > "$warned.$$" && mv "$warned.$$" "$warned"
    openspot toast "Restarting stops $(calls "$calls"). Press again to restart."
    ;;
esac
