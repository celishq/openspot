#!/bin/sh
# icon=cup.and.saucer.fill
# detail=Keep the Mac awake
# shortcut=c
# size=small
# read=panel
record="${TMPDIR:-/tmp}/openspot-caffeinate"
pid=""
end=0
[ -f "$record" ] && read -r pid end < "$record"
case "$(ps -p "${pid:-0}" -o comm= 2>/dev/null)" in
  *caffeinate) running=1 ;;
  *) running=0 ;;
esac

# Writes the record to a temp name, then moves it, so that it is never half written.
remember() {
  echo "$1" > "$record.$$" && mv "$record.$$" "$record"
}

stop() {
  if [ "$running" = 1 ] && ! kill "$pid"; then
    echo "Openspot could not turn off Caffeinate. Try again." >&2
    exit 1
  fi
  rm -f "$record"
  running=0
}

case "$1" in
  read)
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
    printf 'detail=%s\nrecents=false\n\n' "$detail"
    printf 'switch=awake\ntitle=Keep awake\ndetail=%s\non=%s\n\n' "$detail" "$on"
    printf 'button=open\ntitle=Select\n\n'
    if [ "$running" = 1 ]; then
      printf 'row=off\ntitle=Turn off\n\n'
    fi
    printf 'row=1800\ntitle=30 minutes\n\n'
    printf 'row=3600\ntitle=1 hour\n\n'
    printf 'row=7200\ntitle=2 hours\n\n'
    printf 'row=0\ntitle=Until turned off\n'
    ;;
  awake)
    stop
    if [ "$2" = true ]; then
      nohup caffeinate -di >/dev/null 2>&1 &
      remember "$! 0"
      echo "toast=Caffeinate is on until you turn it off"
    else
      echo "toast=Caffeinate is off"
    fi
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
        remember "$! 0"
        echo "toast=Caffeinate is on until you turn it off"
        ;;
      *)
        stop
        nohup caffeinate -di -t "$2" >/dev/null 2>&1 &
        remember "$! $(( $(date +%s) + $2 ))"
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
