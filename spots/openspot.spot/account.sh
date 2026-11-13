#!/bin/sh
# title=Account
# icon=person.crop.circle
# detail=12 words that are your account
# on=sheet.open
# offers=search
# uses=app,account
. "$OPENSPOT_SH"

data=${OPENSPOT_DATA:-${TMPDIR:-/tmp}/openspot-account}
mkdir -p "$data"

# Reads the public facts of the account.
facts() {
  state=$(openspot account --frame) || exit 1
  signed= npub= backed= sync=
  while IFS='=' read -r key value; do
    case $key in
      signedIn) signed=$value ;;
      npub) npub=$value ;;
      backedUp) backed=$value ;;
      sync) sync=$value ;;
    esac
  done <<EOF
$state
EOF
}

# Prints the step to show: the kept one while the account allows it, else the one its state calls for. The words show
# only after a press, so any read, such as a sheet that opens again or the launch, forgets them.
step() {
  [ -z "${OPENSPOT_REASON-}" ] || [ "$(cat "$data/step" 2>/dev/null)" != words ] || rm -f "$data/step"
  saved=$(cat "$data/step" 2>/dev/null)
  case "$saved:$signed:$backed" in
    choose:false:* | restore:false:* | about:false:*) echo "$saved"; return ;;
    about:true:false | words:true:* | check:true:false | restore:true:*) echo "$saved"; return ;;
    account:true:true | leave:true:*) echo "$saved"; return ;;
  esac
  if [ "$signed" != true ]; then
    echo choose
  elif [ "$backed" != true ]; then
    echo about
  else
    echo account
  fi
}

# Keeps the step, and forgets what belonged to the one before.
go() {
  printf '%s' "$1" > "$data/step"
  rm -f "$data/mistake" "$data/pick"
}

# Prints an npub as its first 12 and last 6 letters.
short() {
  printf '%.12s…%s' "$1" "${1#"${1%??????}"}"
}

# Prints a line of words in a tile: its id, title, icon, tone and detail. Over two lines, the detail shows under the title.
line() {
  printf '\ntext=%s\nlook=tile\n' "$1"
  openspot_kv title "$2"
  [ -z "$3" ] || printf 'icon=%s\n' "$3"
  [ -z "$4" ] || printf 'tone=%s\n' "$4"
  if [ -n "$5" ]; then openspot_kv detail "$5"; fi
}

# Prints a button: its id, its title and whether it is the main one, which Command-Return presses.
button() {
  printf '\nbutton=%s\n' "$1"
  openspot_kv title "$2"
  case $3 in
    main) printf 'shortcut=cmd+return\nlook=strong\n' ;;
    close) printf 'close=true\n' ;;
    picked) printf 'look=strong\n' ;;
  esac
}

# Prints a numbered word: its place, the word and its tone.
word() {
  line "w$1" "$2" "$1.circle" "$3"
}

# Prints the layout of this many numbered words, 2 to a line.
word_grid() {
  i=1
  while [ "$i" -le "$1" ]; do
    if [ $((i + 1)) -le "$1" ]; then printf 'grid=w%s w%s\n' "$i" $((i + 1)); else printf 'grid=w%s .\n' "$i"; fi
    i=$((i + 2))
  done
}

# Prints the sign-in step: the field, each typed word, and a line that says how far it is.
restore() {
  facts_of_phrase=
  [ -z "$phrase" ] || facts_of_phrase=$(printf '%s' "$phrase" | openspot account phrase)
  words= unknown= counter= completion= problem= account=
  while IFS='=' read -r key value; do
    case $key in
      word) words="$words$value " ;;
      unknown) unknown=" $value " ;;
      counter) counter=$value ;;
      completion) completion=$value ;;
      problem) problem=$value ;;
      account) account=$value ;;
    esac
  done <<EOF
$facts_of_phrase
EOF
  set -- $words
  printf 'grid=phrase phrase\n'
  word_grid $#
  printf 'grid=status status\ngrid=sign_in back\n'
  [ -z "$toast" ] || openspot_kv toast "$toast"
  printf '\nfield=phrase\ntype=multiline\nplaceholder=Your 12 words, or an nsec\n'
  openspot_kv value "$phrase"
  i=1
  for each in "$@"; do
    case "$unknown" in *" $i "*) word "$i" "$each" bad ;; *) word "$i" "$each" ;; esac
    i=$((i + 1))
  done
  if [ -n "$problem" ]; then
    line status "$problem" exclamationmark.triangle bad
  elif [ -n "$account" ] && [ "$signed" = true ]; then
    line status 'Replaces the account on this Mac' exclamationmark.triangle warn "$(short "$account")"
  elif [ -n "$account" ]; then
    line status 'Signs in as' checkmark.circle good "$(short "$account")"
  elif [ -n "$completion" ]; then
    line status "Did you mean $completion?" questionmark.circle
  else
    line status "${counter:-0 of 12}" textformat.123
  fi
  button sign_in 'Sign in' main
  button back Back
}

# Prints the check step: 4 choices for each of 2 places, each a button whose id holds its place and word.
check() {
  places=$(cat "$data/places" 2>/dev/null)
  set -- $places
  [ $# -eq 2 ] || set -- 1 12
  choices=$(openspot account check "$1" "$2" | sed -n 's/^choice=//p')
  ids= n=0
  for each in $choices; do
    n=$((n + 1))
    if [ "$n" -le 4 ]; then place=$1; else place=$2; fi
    ids="$ids pick-$place-$each"
  done
  set -- "$1" "$2" $ids
  printf 'grid=head head\ngrid=first first\n'
  [ $# -lt 6 ] || printf 'grid=%s %s\ngrid=%s %s\n' "$3" "$4" "$5" "$6"
  printf 'grid=second second\n'
  [ $# -lt 10 ] || printf 'grid=%s %s\ngrid=%s %s\n' "$7" "$8" "$9" "${10}"
  printf 'grid=again again\n'
  [ -z "$toast" ] || openspot_kv toast "$toast"
  if [ -f "$data/mistake" ]; then
    line head "$(cat "$data/mistake")" exclamationmark.triangle bad
  else
    line head 'Pick each word you wrote' checkmark.circle
  fi
  printf '\ntext=first\ntitle=Word %s\nicon=%s.circle\n\ntext=second\ntitle=Word %s\nicon=%s.circle\n' "$1" "$1" "$2" "$2"
  picked=$(cat "$data/pick" 2>/dev/null)
  shift 2
  for id in "$@"; do
    rest=${id#pick-}
    if [ "$picked" = "${rest%%-*} ${rest#*-}" ]; then button "$id" "${rest#*-}" picked; else button "$id" "${rest#*-}"; fi
  done
  button again 'Show the words again'
}

# Prints the frame of the step that shows. $toast is said once, and $phrase is the text of the sign-in field.
sheet() {
  facts
  current=$(step)
  case $current in
    restore) restore; return ;;
    check) check; return ;;
    choose) printf 'grid=head\ngrid=head\ngrid=create\ngrid=sign_in\n' ;;
    about) printf 'grid=head\ngrid=head\ngrid=private\ngrid=reset\ngrid=show\n' ;;
    words) printf 'grid=head head\n'; word_grid 12; printf 'grid=wrote wrote\ngrid=later later\n' ;;
    account)
      printf 'grid=head\ngrid=head\ngrid=backup\n'
      [ -z "$sync" ] || printf 'grid=sync\n'
      printf 'grid=done\ngrid=show\ngrid=leave\n'
      ;;
    leave)
      printf 'grid=head\ngrid=head\n'
      [ "$backed" = true ] || printf 'grid=again\n'
      printf 'grid=sign_out\ngrid=cancel\n'
      ;;
  esac
  [ -z "$toast" ] || openspot_kv toast "$toast"
  case $current in
    choose)
      line head 'Set up your account' signature '' 'Openspot signs what you publish with it, so people can tell an update is yours.'
      button create 'Create account' main
      button sign_in 'Use existing account'
      ;;
    about)
      line head 'Your account is 12 words' key '' 'No email, password or server. Write the words down: they are the only way back in.'
      line private 'Anyone with them is you' eye.slash
      line reset 'Nobody can reset them' exclamationmark.triangle warn
      button show 'Show my words' main
      ;;
    words)
      if words=$(openspot account words 2>&1); then
        line head 'Write them down' pencil '' 'In this order'
        i=1
        for each in $(printf '%s\n' "$words" | sed -n 's/^word=//p'); do
          word "$i" "$each"
          i=$((i + 1))
        done
      else
        line head "$words" exclamationmark.triangle bad
      fi
      button wrote 'I wrote them down' main
      if [ "$backed" = true ]; then button later Done close; else button later Later close; fi
      ;;
    account)
      line head 'Your account' person.crop.circle '' "$npub"
      if [ "$backed" = true ]; then
        line backup 'Your 12 words are backed up' checkmark.shield good
      else
        line backup 'Your 12 words are not backed up' exclamationmark.triangle warn
      fi
      if [ -n "$sync" ]; then printf '\nswitch=sync\ntitle=Keep in iCloud Keychain\nicon=icloud\nlook=tile\nvalue=%s\n' "$sync"; fi
      button done Done main
      printf 'close=true\n'
      button show 'Show my words'
      button leave 'Sign out…'
      ;;
    leave)
      if [ "$sync" = true ]; then where='all your Macs'; else where='this Mac'; fi
      if [ "$backed" = true ]; then again=' Your 12 words sign you in again.'; else again=; fi
      line head 'Sign out of your account?' rectangle.portrait.and.arrow.right '' "It leaves $where.$again"
      [ "$backed" = true ] || line again "You haven't saved its words" exclamationmark.triangle bad
      button sign_out 'Sign out' main
      button cancel Cancel
      ;;
  esac
}

# Picks 2 places of the 12 words, the first one before the second.
places() {
  awk 'BEGIN { srand(); a = int(rand() * 12) + 1; do { b = int(rand() * 12) + 1 } while (b == a); if (a > b) { t = a; a = b; b = t }; print a, b }'
}

toast= phrase=
case "$1" in
  read) sheet ;;
  create) go about; sheet ;;
  sign_in)
    facts
    if [ "$(step)" = restore ]; then
      phrase=$(value phrase)
      if printf '%s' "$phrase" | openspot account sign-in 2>/dev/null; then
        go account
        phrase= toast='Signed in'
      fi
    else
      go restore
    fi
    sheet
    ;;
  phrase) phrase=$2; sheet ;;
  show)
    facts
    if [ "$signed" != true ]; then openspot account new || exit 1; fi
    go words
    sheet
    ;;
  wrote) go check; places > "$data/places"; sheet ;;
  again) go words; sheet ;;
  back) go choose; sheet ;;
  leave) go leave; sheet ;;
  cancel | done | later) rm -f "$data/step"; sheet ;;
  sign_out)
    openspot account sign-out || exit 1
    rm -f "$data/step"
    toast='Signed out'
    sheet
    ;;
  sync)
    if [ "$2" = true ]; then openspot account sync on || exit 1; else openspot account sync off || exit 1; fi
    sheet
    ;;
  pick-*)
    rest=${1#pick-}
    place=${rest%%-*} chosen=${rest#*-}
    first=$(cat "$data/pick" 2>/dev/null)
    case "$first" in
      '' | "$place "*) printf '%s %s' "$place" "$chosen" > "$data/pick" ;;
      *)
        if failure=$(printf '%s\n%s %s\n' "$first" "$place" "$chosen" | openspot account checked 2>&1); then
          go account
          toast='Your words are backed up'
        else
          rm -f "$data/pick"
          printf '%s' "$failure" > "$data/mistake"
        fi
        ;;
    esac
    sheet
    ;;
  *)
    echo 'Account cannot do that.' >&2
    exit 1
    ;;
esac
