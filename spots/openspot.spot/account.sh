#!/bin/sh
# title=Account
# icon=person.crop.circle
# detail=Signs what you publish
# on=panel.open
# on=sheet.open
# offers=search
# uses=app,clipboard

state=$(openspot account status --frame) || exit 1
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
      printf '\nrow=set_up\ntitle=Set up your account\ndetail=Create one, or sign in with your 12 words\nicon=person.crop.circle.badge.plus\n'
      exit 0
    fi
    printf '\nrow=npub\ntitle=Your account\ndetail=%s\nicon=person.crop.circle\n' "$(short "$npub")"
    if [ "$backed" = true ]; then
      printf '\nrow=words\ntitle=Show your words\ndetail=Backed up\nicon=key\n'
    else
      printf '\nrow=words\ntitle=Back up your words\ndetail=Not backed up\nicon=exclamationmark.triangle\n'
    fi
    if [ -n "$sync" ]; then
      printf '\nrow=sync\ntitle=Keep in iCloud Keychain\ndetail=Signs in on your other Macs\nicon=icloud\nvalue=%s\n' "$sync"
    fi
    printf '\nrow=sign_out\ntitle=Sign out\nicon=rectangle.portrait.and.arrow.right\n'
    ;;
  open)
    case "$2" in
      set_up) exec openspot account set-up ;;
      npub)
        printf '%s' "$npub" | openspot clipboard copy || exit 1
        echo 'toast=Copied your account ID'
        ;;
      words) exec openspot account words ;;
      sync)
        if [ "$sync" = true ]; then
          openspot account sync off || exit 1
          echo 'toast=Your account is on this Mac only'
        else
          exec openspot account sync on
        fi
        ;;
      sign_out) exec openspot account sign-out ;;
      *)
        echo 'Account cannot do that.' >&2
        exit 1
        ;;
    esac
    ;;
  *)
    echo 'Account cannot do that.' >&2
    exit 1
    ;;
esac
