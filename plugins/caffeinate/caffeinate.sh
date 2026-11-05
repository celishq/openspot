#!/bin/sh
record="${TMPDIR:-/tmp}/openspot-caffeinate"
pid=""
end=0
[ -f "$record" ] && read -r pid end < "$record"
case "$(ps -p "${pid:-0}" -o comm= 2>/dev/null)" in
  *caffeinate) running=1 ;;
  *) running=0 ;;
esac

stop() {
  if [ "$running" = 1 ] && ! kill "$pid"; then
    echo "Could not turn off Caffeinate." >&2
    exit 1
  fi
  rm -f "$record"
  running=0
}

case "$1" in
  state)
    subtitle="Off"
    on=false
    if [ "$running" = 1 ]; then
      on=true
      subtitle="Until off"
      if [ "$end" != 0 ]; then
        left=$(( (end - $(date +%s) + 59) / 60 ))
        if [ "$left" -ge 60 ]; then
          subtitle="$(( left / 60 ))h $(( left % 60 ))m left"
        else
          subtitle="${left}m left"
        fi
      fi
    fi
    printf 'title=Caffeinate\nsubtitle=%s\non=%s\n' "$subtitle" "$on"
    ;;
  items)
    if [ "$running" = 1 ]; then
      printf 'title=Turn off\nrun=off\n\n'
    fi
    printf 'title=30 minutes\nrun=1800\n\n'
    printf 'title=1 hour\nrun=3600\n\n'
    printf 'title=2 hours\nrun=7200\n\n'
    printf 'title=Until turned off\nrun=0\n'
    ;;
  off)
    stop
    ;;
  0)
    stop
    nohup caffeinate -di >/dev/null 2>&1 &
    echo "$! 0" > "$record"
    ;;
  [0-9]*)
    stop
    nohup caffeinate -di -t "$1" >/dev/null 2>&1 &
    echo "$! $(( $(date +%s) + $1 ))" > "$record"
    ;;
esac
