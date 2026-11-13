#!/bin/sh
# title=Icon
# icon=paintbrush.pointed
# detail=Draw the icon of a spot
# on=sheet.open
# view=icon.swift
# uses=spots
# drop=png,jpg,jpeg,heic,gif,tiff,svg,pdf,icns
#
# button=change
# title=Change Icon
# offers=actions
#
# button=change.draw
# title=Draw…
#
# button=change.file
# title=Choose File…
#
# button=change.reset
# title=Reset Icon
data="$OPENSPOT_DATA/icons"
target=$(cat "$data/target" 2>/dev/null)
name=$(printf '%s' "$target" | tr '/' '_')
empty=$(printf '%144s' '' | tr ' ' '.')

# Prints an SVG of 12 by 12 rounded squares from 144 palette characters, where a square is a digit and an empty place is a dot.
picture() {
  printf '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 12 12">'
  printf '%s\n' "$1" | fold -w 1 | awk '
    BEGIN { split("#1D1D1F #F5F5F7 #FF4A1C #FFC400 #34C759 #0A84FF", colour, " ") }
    $0 ~ /[0-5]/ { printf "<rect x=\"%.2f\" y=\"%.2f\" width=\"0.84\" height=\"0.84\" rx=\"0.22\" fill=\"%s\"/>", (NR - 1) % 12 + 0.08, int((NR - 1) / 12) + 0.08, colour[$0 + 1] }'
  printf '</svg>\n'
}

# Takes the spot's own icon back.
reset() {
  rm -f "$data/$name".*.svg "$data/$name".*.picture.* "$data/$name.dots" "$data/$name.draft"
  openspot setting set --spot "$target" icon
}

case "$1" in
  change.draw|change.file|change.reset)
    mkdir -p "$data"
    printf '%s' "$2" > "$data/target"
    target=$2
    name=$(printf '%s' "$target" | tr '/' '_')
    rm -f "$data/$name.draft"
    case "$1" in
      change.draw) openspot spot open "$OPENSPOT_ID" ;;
      change.file) openspot spot choose "$OPENSPOT_ID" ;;
      change.reset) reset ;;
    esac
    ;;
  drop)
    [ -n "$target" ] || exit 0
    rm -f "$data/$name".*.svg "$data/$name".*.picture.* "$data/$name.dots" "$data/$name.draft"
    file="$data/$name.$(date +%s).picture.${2##*.}"
    cp "$2" "$file"
    openspot setting set --spot "$target" icon "$file"
    ;;
  read)
    [ -n "$target" ] || { printf 'text=none\ntitle=No spot\ndetail=Choose Change Icon in the menu of a card\n'; exit 0; }
    dots=$(cat "$data/$name.draft" 2>/dev/null || cat "$data/$name.dots" 2>/dev/null)
    [ ${#dots} -eq 144 ] || dots=$empty
    printf 'title=%s\ngrid=drawer drawer\ngrid=reset save\n\n' "$target"
    printf 'view=drawer\ndots=%s\n\n' "$dots"
    printf 'button=reset\ntitle=Reset\nclose=true\n\n'
    printf 'button=save\ntitle=Save\nshortcut=return\nlook=strong\nclose=true\n'
    ;;
  drawer)
    [ -n "$target" ] && [ ${#2} -eq 144 ] || exit 0
    printf '%s' "$2" > "$data/$name.draft"
    ;;
  reset)
    [ -n "$target" ] && reset
    ;;
  save)
    [ -n "$target" ] || exit 0
    dots=$(cat "$data/$name.draft" 2>/dev/null || cat "$data/$name.dots" 2>/dev/null)
    [ ${#dots} -eq 144 ] && [ "$dots" != "$empty" ] || { reset; exit 0; }
    rm -f "$data/$name".*.svg "$data/$name".*.picture.* "$data/$name.draft"
    printf '%s' "$dots" > "$data/$name.dots"
    file="$data/$name.$(date +%s).svg"
    picture "$dots" > "$file"
    openspot setting set --spot "$target" icon "$file"
    ;;
esac
