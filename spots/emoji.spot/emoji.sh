#!/bin/sh
export LC_ALL=en_US.UTF-8
. "$OPENSPOT_SH"
saved="$OPENSPOT_DATA/tone"
tones="none light medium-light medium medium-dark dark"
tone=$(cat "$saved" 2>/dev/null)
: "${tone:=none}"

# Writes the tone to a temp name, then moves it, so that it is never half written.
remember() {
  printf '%s\n' "$1" > "$saved.$$" && mv "$saved.$$" "$saved"
}

# Prints the items of the emoji in the tone and of the symbols. It keeps them for each tone, with the times of change of
# the app and of macOS and the languages of the Mac, and makes them again when one of these differs.
glyph_rows() {
  rows="$OPENSPOT_DATA/rows-$tone"
  set -f
  set -- $(defaults read -g AppleLanguages 2>/dev/null)
  set +f
  stamp="$(stat -n -L -f '%Fc ' "$(command -v openspot)" /System/Library/CoreServices/SystemVersion.plist 2>/dev/null)$*"
  kept=''
  [ -f "$rows.stamp" ] && IFS= read -r kept <"$rows.stamp"
  if [ -s "$rows" ] && [ "$stamp" = "$kept" ]; then
    cat "$rows"
    return
  fi
  rm -f "$OPENSPOT_DATA"/rows-*.[0-9]*
  whole=true
  openspot emoji list --tone "$tone" >"$rows.$$" || whole=false
  openspot symbols list >>"$rows.$$" || whole=false
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
  show)
    printf 'frame=\nclass=gap-part\n\nfield=search\ntype=search\n\nchoice=tone\ntitle=Skin tone\nvalue=%s\n\n' "$tone"
    printf 'option=none\ntitle=Yellow\n\noption=light\ntitle=Light\n\noption=medium-light\ntitle=Medium light\n\n'
    printf 'option=medium\ntitle=Medium\n\noption=medium-dark\ntitle=Medium dark\n\noption=dark\ntitle=Dark\n\n'
    printf 'items=a\nclass=grid grid-cols-7\n\n'
    printf 'button=press\nparent=a\ntitle=Copy\n\n'
    printf 'button=paste\nparent=a\ntitle=Paste\nshortcut=cmd+return\n\n'
    printf 'button=next-tone\nparent=a\ntitle=Next skin tone\nshortcut=cmd+t\nscope=spot\nclose=false\n\n'
    # Each glyph sits in the items and shows only its icon: its block gets parent=a and class=sr-only under its first line.
    glyph_rows | awk 'NF && !open { print; print "parent=a"; print "class=sr-only"; open = 1; next } !NF { open = 0 } { print }'
    ;;
  tone)
    remember "$(value value)"
    ;;
  next-tone)
    remember "$(next_tone)"
    ;;
  press)
    printf '%s' "$(value item)" | openspot clipboard copy
    openspot toast Copied
    ;;
  paste)
    previous=$(openspot clipboard read; printf x)
    printf '%s' "$(value item)" | openspot clipboard copy
    openspot clipboard paste || exit 1
    sleep 0.3
    if [ "$previous" != x ]; then
      printf '%s' "${previous%x}" | openspot clipboard copy
    fi
    ;;
esac
