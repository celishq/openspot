#!/bin/sh
# name=Emojis & Symbols
# icon=face.smiling
# subtitle=Copy an emoji or a symbol
# shortcut=e
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
    printf 'grid=tone tone tone tone tone tone tone\ngrid=a a a a a a a\n\nrepeat=a\ngrid=a b c d e f g\n\n'
    printf 'button=open\ntitle=Copy\n\n'
    printf 'button=paste\ntitle=Paste\nshortcut=cmd+return\nclose=true\n\n'
    printf 'button=next-tone\ntitle=Next skin tone\nshortcut=cmd+t\nscope=command\n\n'
    printf 'choice=tone\ntitle=Skin tone\n'
    printf 'option=none:Yellow\noption=light:Light\noption=medium-light:Medium light\noption=medium:Medium\noption=medium-dark:Medium dark\noption=dark:Dark\n'
    printf 'value=%s\n\n' "$tone"
    openspot emoji --tone "$tone"
    openspot symbols
    ;;
  tone)
    remember "$2"
    ;;
  next-tone)
    remember "$(next_tone)"
    ;;
  open)
    printf '%s' "$2" | openspot clipboard copy
    echo "toast=Copied"
    ;;
  paste)
    previous=$(pbpaste; printf x)
    printf '%s' "$2" | openspot clipboard copy
    openspot clipboard paste || exit 1
    sleep 0.3
    if [ "$previous" != x ]; then
      printf '%s' "${previous%x}" | openspot clipboard copy
    fi
    ;;
esac
