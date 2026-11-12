#!/bin/sh
# title=Agenda
# icon=calendar
# detail=Today and tomorrow, with your reminders
# size=large
# on=panel.open
# on=sheet.text
# on=clock.60
# uses=calendar
#
# field=calendars
# icon=calendar
. "$OPENSPOT_SH"

hidden=$(openspot setting get calendars </dev/null)

# Prints a --hide flag for each calendar and list that the person hides in the calendars setting.
hides() { for id in $hidden; do printf -- '--hide %s ' "$id"; done; }

# Turns each calendar or list of the ids on or off, and keeps the ids of the hidden ones in the calendars setting.
toggle() {
  for id in "$@"; do
    next=""
    found=""
    for each in $hidden; do
      if [ "$each" = "$id" ]; then found=1; else next="$next $each"; fi
    done
    [ -n "$found" ] || next="$next $id"
    hidden=${next# }
  done
  if [ -n "$hidden" ]; then
    openspot setting set calendars "$hidden" </dev/null
  else
    openspot setting set calendars </dev/null
  fi
}

# Prints the form that picks the calendars and lists that Agenda shows, with a checkmark on each shown one.
calendars_form() {
  calendars=$(openspot calendar calendars </dev/null) || { printf '%s\n' "$calendars"; exit 1; }
  lists=$(openspot reminders lists </dev/null) || { printf '%s\n' "$lists"; exit 1; }
  printf 'title=Calendars\n\nchoice=calendars\ntitle=Calendars\ntype=multiple\n'
  { printf '%s\n' "$calendars" | sed 's/^row=/row=calendar /'; printf '\n'; printf '%s\n' "$lists" | sed 's/^row=/row=list.bullet /'; } |
    awk -v hidden=" $hidden " 'BEGIN { RS = ""; FS = "\n" }
      /^row=/ {
        split(substr($1, 5), head, " ")
        title = ""; account = ""
        for (i = 2; i <= NF; i++) {
          if ($i ~ /^title=/) title = substr($i, 7)
          if ($i ~ /^detail=/) account = substr($i, 8)
        }
        options = options sprintf("\noption=%s\ntitle=%s · %s\nicon=%s\n", head[2], title, account, head[1])
        if (!index(hidden, " " head[2] " ")) printf "value=%s\n", head[2]
      }
      END { printf "%s", options }'
}

events() { openspot calendar events --days 2 $(hides) </dev/null; }
reminders() { openspot reminders due --days 2 $(hides) </dev/null; }

# Prints one key of the first block of the text.
field() { printf '%s\n' "$2" | sed -n "s/^$1=//p" | head -n 1; }

# Seconds since 1970 of an ISO 8601 time, such as 2026-11-10T09:30:00+01:00.
epoch() { date -j -f '%Y-%m-%dT%H:%M:%S%z' "$(printf '%s' "$1" | sed 's/:\([0-9][0-9]\)$/\1/')" +%s 2>/dev/null; }

# Prints the next event that has a time, or nothing.
next_event() { printf '%s\n' "$events" | awk 'BEGIN { RS = "" } /\nallday=true/ { next } /^row=/ { print; exit }'; }

# Prints the head and the card: the next event in large type across the top, in the colour of its calendar, with its time
# alone on the small card. The strip card adds Join while the event's call is on or starts within 10 minutes, the square
# card a line with the number of open and of late reminders, and the large card a line for each of the first two open
# reminders, with a tick before its title and its due time at the end.
card() {
  next=$(next_event)
  ticks=$(printf '%s\n' "$reminders" | awk 'BEGIN { RS = ""; FS = "\n" } /^row=reminder:/ && /\ndone=false/ && shown < 2 { shown++; print substr($1, 14) }')
  set -- $(printf '%s\n' "$reminders" | awk 'BEGIN { RS = ""; FS = "\n" } /^row=reminder:/ && /\ndone=false/ { open++; if (/\ntone=bad/) late++ } END { print open + 0, late + 0 }')
  open=$1
  late=$2
  join=""
  if [ "$events" = status=unasked ]; then
    value=Allow
    time=Allow
    title='Show your calendar here'
  elif [ -z "$next" ]; then
    value=Free
    time=Free
    title='Nothing on today or tomorrow'
  else
    title=$(field title "$next")
    start=$(epoch "$(field start "$next")")
    left=$(( (start - $(date +%s)) / 60 ))
    time=$(date -r "$start" +%H:%M)
    value=$time
    if [ "$(field tone "$next")" = on ]; then
      value=Now
      time=Now
    elif [ "$left" -lt 60 ]; then
      value="in $left min"
    elif [ "$(date -r "$start" +%F)" != "$(date +%F)" ]; then
      title="$title · tomorrow"
    fi
    if [ -n "$(field meeting "$next")" ] && { [ "$value" = Now ] || [ "$left" -le 10 ]; }; then join=1; fi
  fi
  strip=next
  [ -z "$join" ] || strip='next next next join-now'
  printf 'main=next\nrecents=false\ngrid=items\ngrid.small=at\ngrid.wide=next\ngrid.strip=%s\n' "$strip"
  printf 'grid.square=next next\ngrid.square=next next\ngrid.large=next next next next\ngrid.large=next next next next\n'
  if [ "$late" -gt 0 ]; then
    printf 'grid.square=todo late\n'
  elif [ "$open" -gt 0 ]; then
    printf 'grid.square=todo todo\n'
  fi
  for id in $ticks; do
    printf 'grid.large=%s %s %s due-%s\n' "$id" "$id" "$id" "$id"
  done
  printf '\n'
  color=$(field color "$next")
  printf 'number=next\nvalue=%s\ntitle=%s\ncolor=%s\n\nnumber=at\nvalue=%s\ntitle=%s\n\n' "$value" "$title" "$color" "$time" "$title"
  [ "$open" -eq 0 ] || printf 'text=todo\ntitle=%s to do\n\n' "$open"
  [ "$late" -eq 0 ] || printf 'text=late\ntitle=%s late\ntone=bad\n\n' "$late"
  [ -z "$join" ] || printf 'button=join-now\ntitle=Join\n\n'
  printf '%s\n' "$reminders" | awk 'BEGIN { RS = ""; FS = "\n" }
    /^row=reminder:/ && /\ndone=false/ && shown < 2 {
      shown++
      id = substr($1, 14)
      title = ""; due = ""; tone = ""
      for (i = 2; i <= NF; i++) {
        if ($i ~ /^title=/) title = substr($i, 7)
        if ($i ~ /^detail=/) { due = substr($i, 8); sub(/ · .*/, "", due) }
        if ($i ~ /^tone=/) tone = $i
      }
      printf "switch=%s\ntype=tick\ntitle=%s\nvalue=false\n\ntext=due-%s\ndetail=%s\n", id, title, id, due
      if (tone != "") print tone
      print ""
    }'
}

# Prints the rows of the sheet: the events and the reminders, each with the actions that fit it. With texts,
# such as the typed text and each other form of it, it keeps the rows whose title or detail holds any of them.
rows() {
  printf '%s\n\n%s\n' "$events" "$reminders" | TEXTS=$(printf '%s\n' "$@") awk '
    BEGIN { RS = ""; FS = "\n"; count = split(tolower(ENVIRON["TEXTS"]), texts, "\n") }
    /^row=(event|reminder):/ {
      title = ""; detail = ""; meeting = 0
      for (i = 1; i <= NF; i++) {
        if ($i ~ /^title=/) title = substr($i, 7)
        if ($i ~ /^detail=/) detail = substr($i, 8)
        if ($i ~ /^meeting=/) meeting = 1
      }
      shown = tolower(title " " detail)
      found = count == 0
      for (t = 1; t <= count; t++) if (texts[t] != "" && index(shown, texts[t])) found = 1
      if (!found) next
      print
      if ($1 ~ /^row=reminder:/) print "hides=join"
      else { print "hides=tick"; if (!meeting) print "hides=join" }
      print ""
    }'
}

# Prints a row that adds what the person typed, with what the words will make as its detail.
adding() {
  made=$(openspot "$1" add --dry-run "$2" </dev/null 2>/dev/null) || return 0
  [ "$made" != status=unasked ] || return 0
  printf 'row=add-%s\ntitle=%s\ndetail=%s · %s\nicon=plus.circle\nhides=join\nhides=tick\n\n' "$3" "$4" "$(field title "$made")" "$(field detail "$made")"
}

# Asks macOS for leave with a call outside a read, and shows the link to the fix when the person said no.
allow() {
  out=$(openspot "$@" </dev/null) && return 0
  printf '%s\n' "$out" | grep '^link='
  exit 1
}

case "$1" in
  read)
    events=$(events) || { printf '%s\n' "$events"; exit 1; }
    reminders=$(reminders) || { printf '%s\n' "$reminders"; exit 1; }
    card
    printf 'repeat=items\n\n'
    printf 'button=open\ntitle=Open\n\nbutton=join\ntitle=Join call\nshortcut=cmd+j\nclose=true\n\n'
    printf 'button=tick\ntitle=Mark as done\nshortcut=cmd+shift+c\n\nbutton=calendars\ntitle=Choose calendars\nform=true\nscope=command\n\n'
    typed=$(value search)
    if [ -n "$typed" ]; then
      adding reminders "$typed" reminder 'Add reminder'
      adding calendar "$typed" event 'Add event'
    fi
    [ "$events" != status=unasked ] || printf 'row=allow-calendar\ntitle=Allow Calendar\ndetail=Show your events here\nicon=calendar\nhides=join\nhides=tick\n\n'
    [ "$reminders" != status=unasked ] || printf 'row=allow-reminders\ntitle=Allow Reminders\ndetail=Show and tick your reminders here\nicon=checklist\nhides=join\nhides=tick\n\n'
    rows "$typed" "$(value form)"
    ;;
  open)
    case "$2" in
      allow-calendar) allow calendar events ;;
      allow-reminders) allow reminders due ;;
      add-reminder | add-event)
        noun=reminders
        [ "$2" = add-event ] && noun=calendar
        added=$(openspot "$noun" add "$(value search)" </dev/null) || { printf '%s\n' "$added"; exit 1; }
        printf 'toast=Added %s.\n' "$(field title "$added")"
        ;;
      reminder:*) openspot reminders show "$2" </dev/null ;;
      *) openspot calendar show "$2" </dev/null ;;
    esac
    ;;
  calendars)
    picked=$(value calendars)
    [ -z "$picked" ] || toggle $picked
    calendars_form
    ;;
  tick)
    state=$(reminders | awk -v id="$2" 'BEGIN { RS = ""; FS = "\n" } $1 == "row=" id { for (i = 2; i <= NF; i++) if ($i ~ /^done=/) print substr($i, 6) }')
    to=true
    [ "$state" = true ] && to=false
    openspot reminders done "$2" "$to" </dev/null
    ;;
  join-now)
    events=$(events) || exit 1
    link=$(field meeting "$(next_event)")
    [ -n "$link" ] || { echo 'The next event has no call link.' >&2; exit 1; }
    open "$link"
    ;;
  join)
    link=$(events | awk -v id="$2" 'BEGIN { RS = ""; FS = "\n" } $1 == "row=" id { for (i = 2; i <= NF; i++) if ($i ~ /^meeting=/) print substr($i, 9) }')
    [ -n "$link" ] || { echo 'This event has no call link.' >&2; exit 1; }
    open "$link"
    ;;
  *)
    case "$2" in
      true | false) openspot reminders done "reminder:$1" "$2" </dev/null ;;
    esac
    ;;
esac
