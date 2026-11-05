#!/bin/sh
# symbol=cup.and.saucer.fill
# key=c
# read=open
# recents=false
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
  "")
    detail="Off"
    on=false
    if [ "$running" = 1 ]; then
      on=true
      detail="Until off"
      if [ "$end" != 0 ]; then
        left=$(( (end - $(date +%s) + 59) / 60 ))
        if [ "$left" -ge 60 ]; then
          detail="$(( left / 60 ))h $(( left % 60 ))m left"
        else
          detail="${left}m left"
        fi
      fi
    fi
    printf 'detail=%s\non=%s\n\n' "$detail" "$on"
    printf 'action=open\ntitle=Select\n\n'
    if [ "$running" = 1 ]; then
      printf 'row=Turn off\nrun=off\n\n'
    fi
    printf 'row=30 minutes\nrun=1800\n\n'
    printf 'row=1 hour\nrun=3600\n\n'
    printf 'row=2 hours\nrun=7200\n\n'
    printf 'row=Until turned off\nrun=0\n'
    ;;
  open)
    case "$2" in
      off)
        stop
        echo "toast=Caffeinate is off"
        ;;
      0)
        stop
        nohup caffeinate -di >/dev/null 2>&1 &
        echo "$! 0" > "$record"
        echo "toast=Caffeinate is on until you turn it off"
        ;;
      *)
        stop
        nohup caffeinate -di -t "$2" >/dev/null 2>&1 &
        echo "$! $(( $(date +%s) + $2 ))" > "$record"
        minutes=$(( $2 / 60 ))
        if [ "$minutes" -ge 120 ]; then
          echo "toast=Caffeinate is on for $(( minutes / 60 )) hours"
        elif [ "$minutes" -eq 60 ]; then
          echo "toast=Caffeinate is on for 1 hour"
        elif [ "$minutes" -eq 1 ]; then
          echo "toast=Caffeinate is on for 1 minute"
        else
          echo "toast=Caffeinate is on for $minutes minutes"
        fi
        ;;
    esac
    ;;
esac
