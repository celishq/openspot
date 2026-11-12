#!/bin/sh
# title=Emojis & Symbols
# icon=face.smiling
# detail=Copy an emoji or a symbol
# size=small
# on=sheet.open
# uses=clipboard
export LC_ALL=en_US.UTF-8
saved="$OPENSPOT_DATA/tone"
tones="none light medium-light medium medium-dark dark"
tone=$(cat "$saved" 2>/dev/null)
: "${tone:=none}"

# Writes the tone to a temp name, then moves it, so that it is never half written.
remember() {
  printf '%s\n' "$1" > "$saved.$$" && mv "$saved.$$" "$saved"
}

# Prints the rows of the emoji in the tone and of the symbols. It keeps them for each tone, with the times of change of
# the app, of macOS and of the Mac's preferences, which hold its languages, and makes them again when one of these differs.
glyph_rows() {
  rows="$OPENSPOT_DATA/rows-$tone"
  stamp=$(stat -n -L -f '%Fc ' "$(command -v openspot)" /System/Library/CoreServices/SystemVersion.plist "$HOME/Library/Preferences/.GlobalPreferences.plist" 2>/dev/null)
  kept=''
  [ -f "$rows.stamp" ] && IFS= read -r kept <"$rows.stamp"
  if [ -s "$rows" ] && [ "$stamp" = "$kept" ]; then
    cat "$rows"
    return
  fi
  rm -f "$OPENSPOT_DATA"/rows-*.[0-9]*
  whole=true
  openspot emoji --tone "$tone" >"$rows.$$" || whole=false
  openspot symbols >>"$rows.$$" || whole=false
  cat "$rows.$$"
  if [ "$whole" = true ]; then
    mv "$rows.$$" "$rows"
    printf '%s\n' "$stamp" >"$rows.stamp"
  else
    rm -f "$rows.$$"
  fi
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
    printf 'button=next-tone\ntitle=Next skin tone\nshortcut=cmd+t\nscope=spot\n\n'
    printf 'choice=tone\ntitle=Skin tone\nvalue=%s\n\n' "$tone"
    printf 'option=none\ntitle=Yellow\n\noption=light\ntitle=Light\n\noption=medium-light\ntitle=Medium light\n\n'
    printf 'option=medium\ntitle=Medium\n\noption=medium-dark\ntitle=Medium dark\n\noption=dark\ntitle=Dark\n\n'
    glyph_rows
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
    previous=$(openspot clipboard read; printf x)
    printf '%s' "$2" | openspot clipboard copy
    openspot clipboard paste || exit 1
    sleep 0.3
    if [ "$previous" != x ]; then
      printf '%s' "${previous%x}" | openspot clipboard copy
    fi
    ;;
esac
