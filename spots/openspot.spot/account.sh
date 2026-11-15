#!/bin/sh
# title=Account
# icon=person.crop.circle
# detail=Signs what you publish
# on=sheet.open
# mode=stay
# uses=account,clipboard
# view=openspot:account-card
# pages=publish:*
# pages=how
# pages=handle*
# pages=restore*
# pages=about
# pages=check:*
# pages=leave
# offers=search

# The account that signs what you publish. Each step is a page, and the first sheet shows the account, or the choice of
# a new key or your own. A store that publishes with no key pushes `publish:<id>`, and the step that makes the key then
# publishes that spot and goes back.
#
# The 12 words never reach an argument, a file or a log. This spot stays, so each call and what the person typed come
# on its stdin, and it hands the words to `openspot account` on stdin too. It reads them from the text of the call in
# memory, with no here-document, which the shell would write to a file. The calls of a spot with the `account` use stay
# out of the call log, and no toast or failure of this spot holds a word.
. "$OPENSPOT_SH"
nl='
'

# Prints the value of a key of the call's stdin, from the text in memory.
field() {
  rest="$nl$_openspot_stdin"
  case $rest in *"$nl$1="*) ;; *) return 0 ;; esac
  rest=${rest#*"$nl$1="}
  _openspot_decode "${rest%%"$nl"*}"
  printf '%s' "$_openspot_text"
}

# Prints the last line of a text, such as the reason of a failed `openspot` call.
last() {
  printf '%s' "${1##*"$nl"}"
}

# Sets the facts of the account: signed_in, npub, handle, since, backed_up and sync.
facts() {
  signed_in=false npub= handle= since= backed_up= sync=
  rest="$(openspot account --frame)$nl"
  while [ -n "$rest" ]; do
    line=${rest%%"$nl"*} rest=${rest#*"$nl"}
    case $line in
      signedIn=*) signed_in=${line#*=} ;;
      npub=*) npub=${line#*=} ;;
      handle=*) handle=${line#*=} ;;
      since=*) since=${line#*=} ;;
      backedUp=*) backed_up=${line#*=} ;;
      sync=*) sync=${line#*=} ;;
    esac
  done
}

# The spot that a step publishes when it ends, from a page such as `publish:<id>` or `handle:<id>`.
publishing() {
  case $OPENSPOT_PAGE in
    publish:*) printf '%s' "${OPENSPOT_PAGE#publish:}" ;;
    handle:* | restore:*) printf '%s' "${OPENSPOT_PAGE#*:}" ;;
  esac
}

short() {
  printf '%s…%s' "${1%"${1#?????????}"}" "${1#"${1%????}"}"
}

# Prints a text block in the look of a tile: id, title, icon, tone and detail.
line() {
  printf '\ntext=%s\nlook=tile\n' "$1"
  openspot_kv title "$2"
  [ -z "${3-}" ] || openspot_kv icon "$3"
  [ -z "${4-}" ] || openspot_kv tone "$4"
  [ -z "${5-}" ] || openspot_kv detail "$5"
}

# Prints a button: id, title, and `main` for the strong one on ⌘⏎, `close` for one that closes the panel, or `picked`.
button() {
  printf '\nbutton=%s\n' "$1"
  openspot_kv title "$2"
  case ${3-} in
    main) printf 'shortcut=cmd+return\nlook=strong\n' ;;
    close) printf 'close=true\n' ;;
    picked) printf 'look=strong\n' ;;
  esac
}

how_action() {
  printf '\nbutton=how\ntitle=How it works\nscope=spot\n'
}

# Moves to a step: pushed over the sheet, or in its place when a store waits for the key, so that the end of the step
# goes back to that store.
step() {
  id=$(publishing)
  if [ -n "$id" ]; then printf 'push=%s:%s\npush.replace=true\n\n' "$1" "$id"; else printf 'push=%s\n\n' "$1"; fi
}

# Goes back from a step: to the choice again when a store waits for the key, else one sheet back.
back() {
  id=$(publishing)
  if [ -n "$id" ]; then printf 'push=publish:%s\npush.replace=true\n\n' "$id"; else printf 'pop=true\n\n'; fi
}

# Ends a step that made or brought back the key. It publishes the spot that a store waits for, and goes back there.
finish() {
  id=$(publishing)
  if [ -n "$id" ]; then
    openspot store publish "$id" >/dev/null 2>&1
    printf 'pop=true\n'
  else
    printf 'pop=all\n'
  fi
  [ -z "${1-}" ] || openspot_kv toast "$1"
  printf '\n'
}

choose() {
  printf 'grid=head head\ngrid=head head\ngrid=new new\ngrid=own how\n'
  line head "You need a key to publish" signature "" "Openspot signs your spots with it, so people know an update is from you."
  button new "Create a new key" main
  button own "Use my own key"
  how_action
}

clean() {
  printf '%s' "$1" | /usr/bin/tr 'A-Z' 'a-z' | /usr/bin/tr -cd 'a-z0-9_-' | /usr/bin/cut -c1-20
}

is_handle() {
  [ ${#1} -ge 3 ] && [ ${#1} -le 20 ]
}

handle_page() {
  problem=
  [ -z "${2-}" ] || is_handle "$1" || problem="A handle has 3 to 20 of a–z, 0–9, - and _."
  printf 'grid=head head\ngrid=head head\ngrid=label label\ngrid=handle handle\n'
  [ -z "$problem" ] || printf 'grid=status status\n'
  printf 'grid=back create\n'
  line head "Pick your handle" at "" "It names you on the spots you publish, and in their links."
  printf '\nsection=label\ntitle=Handle\n\nfield=handle\ngrow=false\nplaceholder=yourname\n'
  openspot_kv value "$1"
  [ -z "$problem" ] || line status "$problem" exclamationmark.triangle bad
  button back "Back"
  button create "Create key" main
  how_action
}

how_page() {
  printf 'grid=head\ngrid=head\ngrid=people\ngrid=icloud\ngrid=words\ngrid=private\ngrid=reset\ngrid=done\n'
  line head "How your key works" key "" "Openspot signs each spot you publish with your key. There is no email, password or server."
  line people "Shows an update is yours" checkmark.seal
  line icloud "Kept in iCloud Keychain" icloud
  line words "12 words bring it back" list.number
  line private "Anyone with the words is you" eye.slash
  line reset "Nobody can reset them" exclamationmark.triangle warn
  button done "Done" main
}

about_page() {
  printf 'grid=head\ngrid=head\ngrid=private\ngrid=reset\n'
  [ "$sync" != true ] || printf 'grid=icloud\n'
  printf 'grid=show\n'
  line head "Your 12 words are your key" key "" "They bring your key back on any Mac."
  line private "Anyone with them is you" eye.slash
  line reset "Nobody can reset them" exclamationmark.triangle warn
  [ "$sync" != true ] || line icloud "iCloud Keychain keeps a copy" icloud
  button show "Show my words" main
  how_action
}

# Shows the 12 words after Touch ID. Only a press shows them, and a staying spot keeps the frame of a press until the
# next read, so a sheet that opens again shows its page with no word.
words() {
  printf 'grid=head head\ngrid=w1 w2\ngrid=w3 w4\ngrid=w5 w6\ngrid=w7 w8\ngrid=w9 w10\ngrid=w11 w12\ngrid=wrote wrote\ngrid=later later\n'
  if shown=$(openspot account words 2>&1); then
    line head "Write them down" pencil "" "In this order"
    place=0 rest="$shown$nl"
    while [ -n "$rest" ]; do
      word=${rest%%"$nl"*} rest=${rest#*"$nl"}
      case $word in word=*) ;; *) continue ;; esac
      place=$((place + 1))
      line "w$place" "${word#word=}" "$place.circle"
    done
  else
    line head "$(last "$shown")" exclamationmark.triangle bad
  fi
  button wrote "I wrote them down" main
  if [ "$backed_up" = true ]; then button later "Done" close; else button later "Later" close; fi
  how_action
}

account_page() {
  printf 'grid=card card\ngrid=card card\ngrid=card card\ngrid=card card\ngrid=backup backup\n'
  [ -z "$sync" ] || printf 'grid=sync sync\n'
  printf 'grid=about about\ngrid=- -\ngrid=how leave\n'
  printf '\nview=card\ngrow=false\n'
  openspot_kv npub "$npub"
  openspot_kv short "$(short "$npub")"
  [ -z "$handle" ] || openspot_kv handle "$handle"
  [ -z "$since" ] || openspot_kv since "$(LC_ALL=en_US_POSIX /bin/date -j -f %Y-%m-%d "$since" '+%b %Y' 2>/dev/null)"
  printf '\nsection=backup\ntitle=Backup\n'
  [ -z "$sync" ] || printf '\nswitch=sync\ntitle=Keep in iCloud Keychain\nicon=icloud\nlook=tile\nvalue=%s\n' "$sync"
  printf '\nbutton=about\ntitle=Recovery words\nicon=key\nlook=tile\n'
  if [ "$backed_up" = true ]; then printf 'detail=Saved\ntone=good\n'
  elif [ "$sync" = true ]; then printf 'detail=In iCloud Keychain\n'
  else printf 'detail=Not saved yet\ntone=warn\n'
  fi
  button how "How it works"
  button leave "Sign out…"
}

leave_page() {
  printf 'grid=head\ngrid=head\n'
  [ "$backed_up" = true ] || printf 'grid=again\n'
  printf 'grid=sign_out\ngrid=cancel\n'
  if [ "$sync" = true ]; then where="all your Macs"; else where="this Mac"; fi
  if [ "$backed_up" = true ]; then again=" Your 12 words sign you in again."; else again=; fi
  line head "Sign out of your account?" rectangle.portrait.and.arrow.right "" "It leaves $where.$again"
  [ "$backed_up" = true ] || line again "You haven't saved its words" exclamationmark.triangle bad
  button sign_out "Sign out" main
  button cancel "Cancel"
  how_action
}

# Sets `account` and `status`, with its icon, tone and detail, from what Openspot says of a typed phrase. A word still
# being typed is not wrong yet.
judge() {
  account= status= icon= tone= detail=
  [ -n "$1" ] || return 0
  count=0 unknown= completion= problem= counter=
  rest="$(printf '%s' "$1" | openspot account phrase)$nl"
  while [ -n "$rest" ]; do
    line=${rest%%"$nl"*} rest=${rest#*"$nl"}
    case $line in
      word=*) count=$((count + 1)); eval "typed_$count=\${line#word=}" ;;
      unknown=*) unknown=${line#*=} ;;
      completion=*) completion=${line#*=} ;;
      problem=*) problem=${line#*=} ;;
      account=*) account=${line#*=} ;;
      counter=*) counter=${line#*=} ;;
    esac
  done
  case $1 in *[[:space:]]) typing= ;; *) typing=$count ;; esac
  first=
  for place in $unknown; do [ "$place" = "$typing" ] || { first=$place; break; }; done
  if [ -n "$problem" ]; then status=$problem icon=exclamationmark.triangle tone=bad account=
  elif [ -n "$account" ] && [ "$signed_in" = true ]; then status="Replaces the account on this Mac" icon=exclamationmark.triangle tone=warn detail=$(short "$account")
  elif [ -n "$account" ]; then status="Signs in as" icon=checkmark.circle tone=good detail=$(short "$account")
  elif [ -n "$first" ]; then eval "status=\"\$typed_$first isn't an account word\""; icon=exclamationmark.triangle tone=bad
  elif [ -n "$completion" ]; then status="Did you mean $completion?" icon=questionmark.circle
  else status=$counter
  fi
}

# Shows the field of the 12 words or the nsec, and what `judge` said of it.
restore() {
  printf 'grid=phrase phrase\ngrid=phrase phrase\ngrid=phrase phrase\n'
  [ -z "$status" ] || printf 'grid=status status\n'
  printf 'grid=back sign_in\n'
  printf '\nfield=phrase\ntype=multiline\ngrow=false\nplaceholder=Your 12 words, or an nsec\n'
  openspot_kv value "$1"
  [ -z "$status" ] || line status "$status" "$icon" "$tone" "$detail"
  button sign_in "Sign in" main
  button back "Back"
}

# The two places of a check page `check:<place>-<place>[:<pick>]`, and its pick: `<place>-<number>` or `wrong`.
check_places() {
  places=${OPENSPOT_PAGE#check:}
  pick=${places#*:}
  [ "$pick" != "$places" ] || pick=
  places=${places%%:*}
  one=${places%-*} two=${places#*-}
}

# Shows four words for each of the two places. A button holds the number of its word, never the word.
check() {
  check_places
  printf 'grid=head head\ngrid=first first\ngrid=pick-%s-1 pick-%s-2\ngrid=pick-%s-3 pick-%s-4\n' "$one" "$one" "$one" "$one"
  printf 'grid=second second\ngrid=pick-%s-1 pick-%s-2\ngrid=pick-%s-3 pick-%s-4\ngrid=again again\n' "$two" "$two" "$two" "$two"
  if ! choices=$(openspot account choices "$one" "$two" 2>&1); then
    line head "$(last "$choices")" exclamationmark.triangle bad
    button again "Show the words again"
    return 0
  fi
  if [ "$pick" = wrong ]; then
    line head "One of these words is wrong. Look at your words again." exclamationmark.triangle bad
  else
    line head "Pick each word you wrote" checkmark.circle
  fi
  printf '\ntext=first\ntitle=Word %s\nicon=%s.circle\n' "$one" "$one"
  printf '\ntext=second\ntitle=Word %s\nicon=%s.circle\n' "$two" "$two"
  rest="$choices$nl"
  while [ -n "$rest" ]; do
    set -- ${rest%%"$nl"*}
    rest=${rest#*"$nl"}
    [ $# -eq 5 ] || continue
    place=$1
    shift
    number=0
    for word; do
      number=$((number + 1))
      if [ "$pick" = "$place-$number" ]; then button "pick-$place-$number" "$word" picked; else button "pick-$place-$number" "$word"; fi
    done
  done
  button again "Show the words again"
}

# Prints the place and the word of each pick `<place>-<number>`, one a line, from the choices for the page.
picked_words() {
  rest="$(openspot account choices "$one" "$two")$nl"
  while [ -n "$rest" ]; do
    set -- ${rest%%"$nl"*}
    rest=${rest#*"$nl"}
    for pick in "$first_pick" "$second_pick"; do
      [ "$1" = "${pick%-*}" ] || continue
      eval "printf '%s %s\n' \"\$1\" \"\${$((${pick#*-} + 1))}\""
    done
  done
}

# Takes a pick of the check. The page keeps the first, and the second checks both, so the words are backed up when
# both are right.
choose_word() {
  check_places
  case $pick in
    "" | wrong | "${1%-*}"-*) printf 'push=check:%s:%s\npush.replace=true\n\n' "$places" "$1"; return 0 ;;
  esac
  first_pick=$pick second_pick=$1
  if picked_words | openspot account checked >/dev/null 2>&1; then
    printf 'pop=all\ntoast=Your words are backed up\n\n'
  else
    printf 'push=check:%s:wrong\npush.replace=true\n\n' "$places"
  fi
}

two_places() {
  /usr/bin/awk 'BEGIN { srand(); a = int(rand() * 12) + 1; do b = int(rand() * 12) + 1; while (b == a); if (a > b) { c = a; a = b; b = c }; printf "%d-%d", a, b }'
}

# Prints the sheet of the page that shows.
page() {
  case $OPENSPOT_PAGE in
    how) how_page ;;
    handle*) handle_page "$(clean "$(/usr/bin/id -F 2>/dev/null || printf '%s' "$USER")")" ;;
    restore*) judge ""; restore "" ;;
    about) about_page ;;
    check:*) check ;;
    leave) leave_page ;;
    *) if [ "$signed_in" = true ]; then account_page; else choose; fi ;;
  esac
}

main() {
  facts
  case $1 in
    read) page ;;
    new) step handle ;;
    own) step restore ;;
    how) printf 'push=how\n\n' ;;
    about | leave) printf 'push=%s\n\n' "$1" ;;
    done | cancel) printf 'pop=true\n\n' ;;
    back) back ;;
    handle) handle_page "$(clean "${2-}")" checks ;;
    create)
      typed=$(clean "$(field handle)")
      if is_handle "$typed" && openspot account new "$typed" >/dev/null 2>&1; then finish; else handle_page "$typed" checks; fi
      ;;
    phrase)
      phrase=$(field phrase)
      judge "$phrase"
      restore "$phrase"
      ;;
    sign_in)
      phrase=$(field phrase)
      judge "$phrase"
      if [ -n "$account" ] && printf '%s' "$phrase" | openspot account sign-in >/dev/null 2>&1; then
        finish "Signed in"
      else
        restore "$phrase"
      fi
      ;;
    card) [ "${2-}" = copy ] && printf '%s' "$npub" | openspot clipboard copy >/dev/null 2>&1 && printf 'toast=Copied your key\n\n' ;;
    sync)
      if [ "${2-}" = true ]; then turn=on; else turn=off; fi
      if said=$(openspot account sync "$turn" 2>&1); then facts; else openspot_kv toast "$(last "$said")"; fi
      printf '\n'
      page
      ;;
    show | again) words ;;
    wrote) if [ "$sync" = true ]; then printf 'pop=all\n\n'; else printf 'push=check:%s\n\n' "$(two_places)"; fi ;;
    later) printf 'pop=all\n\n' ;;
    sign_out)
      if said=$(openspot account sign-out 2>&1); then printf 'pop=all\ntoast=Signed out\n\n'; else openspot_kv toast "$(last "$said")"; fi
      ;;
    pick-*) choose_word "${1#pick-}" ;;
    *)
      echo 'Account cannot do that.' >&2
      return 1
      ;;
  esac
}

# Runs `main` once with the arguments, or in a staying process once for each call on stdin. A call's stdin stays in
# memory: `main` reads it with `field` and gets no stdin of its own.
if [ -z "$_openspot_stays" ]; then
  main "$@" </dev/null
  exit
fi
while _openspot_next; do
  set --
  rest=$_openspot_args
  while [ "$_openspot_count" -gt 0 ]; do
    _openspot_decode "${rest%%"$nl"*}"
    set -- "$@" "$_openspot_text"
    case $rest in *"$nl"*) rest=${rest#*"$nl"} ;; *) break ;; esac
  done
  printf 'call=%s\n---\n' "$_openspot_call"
  main "$@" </dev/null
  printf '\n---\nend=%s\n---\n' "$_openspot_call"
done
