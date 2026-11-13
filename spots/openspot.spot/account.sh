#!/bin/sh
# title=Account
# icon=person.crop.circle
# detail=12 words that are your account
# on=panel.open
# on=sheet.open
# offers=search
# uses=app,account
# view=account.swift

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

# Prints the step to show: the kept one while the account allows it, else the one its state calls for.
step() {
  saved=$(cat "$data/step" 2>/dev/null)
  case "$saved:$signed:$backed" in
    choose:false:* | restore:false:* | about:false:*) echo "$saved"; return ;;
    about:true:false | words:true:* | check:true:false) echo "$saved"; return ;;
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
  rm -f "$data/mistake"
}

# Prints a button: its id, its title and whether it is the main one.
button() {
  printf '\nbutton=%s\ntitle=%s\n' "$1" "$2"
  case $3 in
    main) printf 'shortcut=cmd+return\nlook=strong\n' ;;
    close) printf 'close=true\n' ;;
  esac
}

# Prints the frame of the step: the layout, the view with what it draws, and the buttons. $1 is a toast, and $2 the
# facts of a phrase that the person is typing.
sheet() {
  facts
  current=$(step)
  buttons=
  case $current in
    choose) buttons="create sign_in" ;;
    about) buttons=show ;;
    words) buttons="wrote later" ;;
    check) buttons=again ;;
    restore) buttons="nsec back" ;;
    account) buttons="done show leave" ;;
    leave) buttons="sign_out cancel" ;;
  esac
  printf 'grid=steps\n'
  [ "$current" != account ] || [ -z "$sync" ] || printf 'grid=sync\n'
  for id in $buttons; do printf 'grid=%s\n' "$id"; done
  [ -z "$1" ] || printf 'toast=%s\n' "$1"
  printf '\nview=steps\nstep=%s\n' "$current"
  [ ! -f "$data/mistake" ] || printf 'mistake=%s\n' "$(cat "$data/mistake")"
  case $current in
    words)
      if [ "$OPENSPOT_REASON" != panel.open ]; then
        words=$(openspot account words 2>&1) && printf '%s\n' "$words" || printf 'mistake=%s\n' "$words"
      fi
      ;;
    check)
      places=$(cat "$data/places" 2>/dev/null)
      [ -n "$places" ] || places="1 12"
      if [ "$OPENSPOT_REASON" != panel.open ]; then
        openspot account check $places | grep -E '^(check|choice)='
      fi
      ;;
    restore)
      [ ! -f "$data/nsec" ] || printf 'mode=nsec\n'
      [ -z "$2" ] || printf '%s\n' "$2"
      ;;
    account)
      printf 'npub=%s\nbacked=%s\n' "$npub" "$backed"
      ;;
    leave)
      if [ "$sync" = true ]; then
        printf 'place=this Mac and from your other Macs that use iCloud Keychain\n'
      else
        printf 'place=this Mac\n'
      fi
      ;;
  esac
  case $current in
    choose) button create 'Create account' main; button sign_in 'Use existing account' ;;
    about) button show 'Show my words' main ;;
    words)
      button wrote 'I wrote them down' main
      if [ "$backed" = true ]; then button later Done close; else button later Later close; fi
      ;;
    check) button again 'Show the words again' ;;
    restore)
      if [ -f "$data/nsec" ]; then button nsec 'Use your 12 words'; else button nsec 'Use an nsec instead'; fi
      button back Back
      ;;
    account)
      if [ -n "$sync" ]; then printf '\nswitch=sync\ntitle=Keep in iCloud Keychain\nvalue=%s\n' "$sync"; fi
      button done Done close
      button show 'Show my words'
      button leave 'Sign out…'
      ;;
    leave) button sign_out 'Sign out' main; button cancel Cancel ;;
  esac
}

# Picks 2 places of the 12 words, the first one before the second.
places() {
  awk 'BEGIN { srand(); a = int(rand() * 12) + 1; do { b = int(rand() * 12) + 1 } while (b == a); if (a > b) { t = a; a = b; b = t }; print a, b }'
}

case "$1" in
  read) sheet ;;
  create) go about; sheet ;;
  sign_in) rm -f "$data/nsec"; go restore; sheet ;;
  show)
    facts
    if [ "$signed" != true ]; then openspot account new || exit 1; fi
    go words
    sheet
    ;;
  wrote) places > "$data/places"; go check; sheet ;;
  again) go words; sheet ;;
  nsec)
    if [ -f "$data/nsec" ]; then rm -f "$data/nsec"; else : > "$data/nsec"; fi
    sheet
    ;;
  back) go choose; sheet ;;
  leave) go leave; sheet ;;
  cancel | done | later) go account; rm -f "$data/step"; sheet ;;
  sign_out)
    if openspot account sign-out; then
      rm -f "$data/step"
      sheet 'Signed out'
    else
      exit 1
    fi
    ;;
  sync)
    if [ "$2" = true ]; then openspot account sync on || exit 1; else openspot account sync off || exit 1; fi
    sheet
    ;;
  steps)
    case $2 in
      phrase\ *) sheet '' "$(printf '%s' "${2#phrase }" | openspot account phrase)" ;;
      sign-in\ *)
        if failure=$(printf '%s' "${2#sign-in }" | openspot account sign-in 2>&1); then
          go account
          sheet 'Signed in'
        else
          sheet '' "problem=$failure"
        fi
        ;;
      checked\ *)
        set -- ${2#checked }
        if failure=$(printf '%s %s\n%s %s\n' "$1" "$2" "$3" "$4" | openspot account checked 2>&1); then
          go account
          sheet 'Your words are backed up'
        else
          printf '%s' "$failure" > "$data/mistake"
          sheet
        fi
        ;;
    esac
    ;;
  *)
    echo 'Account cannot do that.' >&2
    exit 1
    ;;
esac
