#!/bin/sh
# title=Account
# icon=person.crop.circle
# detail=12 words that are your account
# on=panel.open
# on=sheet.open
# offers=search
# uses=app

state=$(openspot account --frame) || exit 1
signed= npub= backed= sync=
while IFS='=' read -r key value; do
  case $key in
    signedIn) signed=$value ;;
    npub) npub=$value ;;
    backedUp) backed=$value ;;
    sync) sync=$value ;;
  esac
done <<EOF2
$state
EOF2

# Prints an npub as its first 12 and last 6 letters.
short() {
  printf '%.12s…%s' "$1" "${1#"${1%??????}"}"
}

case "$1" in
  read)
    printf 'recents=false\n'
    if [ "$signed" != true ]; then
      printf '\nrow=account\ntitle=Set up your account\ndetail=Signs what you publish\nicon=person.crop.circle.badge.plus\n'
      exit 0
    fi
    printf '\nrow=account\ntitle=Your account\ndetail=%s\nicon=person.crop.circle\n' "$(short "$npub")"
    if [ "$backed" = true ]; then
      printf '\nrow=backup\ntitle=Backed up\ndetail=Your 12 words are saved\nicon=checkmark.shield\n'
    else
      printf '\nrow=backup\ntitle=Back up your words\ndetail=Not backed up\nicon=exclamationmark.triangle\n'
    fi
    if [ -n "$sync" ]; then
      printf '\nrow=sync\ntitle=Keep in iCloud Keychain\ndetail=Signs in on your other Macs\nicon=icloud\nvalue=%s\n' "$sync"
    fi
    ;;
  open)
    case "$2" in
      sync)
        if [ "$sync" = true ]; then
          openspot account sync off || exit 1
          echo 'toast=Your account is on this Mac only'
        else
          exec openspot account sync on
        fi
        ;;
      *) exec openspot account open ;;
    esac
    ;;
  *)
    echo 'Account cannot do that.' >&2
    exit 1
    ;;
esac
