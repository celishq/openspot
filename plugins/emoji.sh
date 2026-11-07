#!/bin/sh
# name=Emoji
# symbol=face.smiling
# subtitle=Copy an emoji
# key=e
# size=small
# read=sheet
export LC_ALL=en_US.UTF-8
saved="$OPENSPOT_DATA/tone"
tones="none light medium-light medium medium-dark dark"
tone=$(cat "$saved" 2>/dev/null)
: "${tone:=none}"

# Writes the tone to a temp name, then moves it, so that it is never half written.
remember() {
  printf '%s\n' "$1" > "$saved.$$" && mv "$saved.$$" "$saved"
}

# Prints the tone after this one, and the first after the last.
next_tone() {
  set -- $tones $tones
  while [ "$1" != "$tone" ]; do shift; done
  printf '%s' "$2"
}

case "$1" in
  read)
    printf 'grid=t t t t t t t\ngrid=a a a a a a a\nrepeat=a 7\n\n'
    printf 'action=open\ntitle=Copy\n\n'
    printf 'action=paste\ntitle=Paste\nkey=cmd+return\nclose=true\n\n'
    printf 'action=next-tone\ntitle=Next skin tone\nkey=cmd+t\nscope=command\n\n'
    printf 'part=tone\ncell=t\ntitle=Skin tone\n'
    printf 'option=none:Yellow\noption=light:Light\noption=medium-light:Medium light\noption=medium:Medium\noption=medium-dark:Medium dark\noption=dark:Dark\n'
    printf 'value=%s\n\n' "$tone"
    openspot emoji --tone "$tone"
    ;;
  tone)
    remember "$2"
    ;;
  next-tone)
    remember "$(next_tone)"
    ;;
  open)
    printf '%s' "$2" | pbcopy
    echo "toast=Copied"
    ;;
  paste)
    previous=$(pbpaste; printf x)
    printf '%s' "$2" | pbcopy
    sleep 0.2
    if ! osascript -e 'tell application "System Events" to keystroke "v" using command down' 2>/dev/null; then
      printf 'open=x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility\n'
      echo 'Copied, but Openspot cannot paste. Press `⌘V`, or allow Openspot in Accessibility.' >&2
      exit 1
    fi
    sleep 0.3
    if [ "$previous" != x ]; then
      printf '%s' "${previous%x}" | pbcopy
    fi
    ;;
esac
