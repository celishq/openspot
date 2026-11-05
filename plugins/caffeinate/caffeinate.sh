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
  [ "$running" = 1 ] && kill "$pid"
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
    printf '{"title":"Caffeinate","subtitle":"%s","on":%s}\n' "$subtitle" "$on"
    ;;
  items)
    echo '{"title":"30 minutes","run":"1800"}'
    echo '{"title":"1 hour","run":"3600"}'
    echo '{"title":"2 hours","run":"7200"}'
    echo '{"title":"Until turned off","run":"0"}'
    if [ "$running" = 1 ]; then
      echo '{"title":"Turn off","run":"off"}'
    fi
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
