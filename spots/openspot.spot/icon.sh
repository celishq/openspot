#!/bin/sh
# title=Icon
# icon=paintbrush.pointed
# detail=Draw the icon of a spot
# on=sheet.open
# view=icon.swift
# uses=spots
# drop=png,jpg,jpeg,heic,gif,tiff,svg,pdf,icns
# offers=none
data="$OPENSPOT_DATA/icons"
target=$(cat "$data/target" 2>/dev/null)
name=$(printf '%s' "$target" | tr '/' '_')
empty=$(printf '%81s' '' | tr ' ' '.')

# Prints an SVG of 9 by 9 rounded squares from 81 palette characters, where a square is a digit and an empty place is a dot.
picture() {
  printf '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 9 9">'
  printf '%s\n' "$1" | fold -w 1 | awk '
    BEGIN { split("#1D1D1F #F5F5F7 #FF4A1C #FFC400 #34C759 #0A84FF", colour, " ") }
    $0 ~ /[0-5]/ { printf "<rect x=\"%.2f\" y=\"%.2f\" width=\"0.84\" height=\"0.84\" rx=\"0.22\" fill=\"%s\"/>", (NR - 1) % 9 + 0.08, int((NR - 1) / 9) + 0.08, colour[$0 + 1] }'
  printf '</svg>\n'
}

# Takes the spot's own icon back.
reset() {
  rm -f "$data/$name".*.svg "$data/$name".*.picture.* "$data/$name.dots" "$data/$name.draft"
  openspot setting set --spot "$target" icon
}

case "$1" in
  draw|file|reset)
    mkdir -p "$data"
    printf '%s' "$2" > "$data/target"
    target=$2
    name=$(printf '%s' "$target" | tr '/' '_')
    rm -f "$data/$name.draft"
    case "$1" in
      draw) openspot spot open "$OPENSPOT_ID" ;;
      file) openspot spot choose "$OPENSPOT_ID" ;;
      reset) reset ;;
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
    [ -n "$target" ] || { printf 'text=none\ntitle=No spot\ndetail=Choose Change Icon › Draw… in the menu of a card\n'; exit 0; }
    dots=$(cat "$data/$name.draft" 2>/dev/null || cat "$data/$name.dots" 2>/dev/null)
    [ ${#dots} -eq 81 ] || dots=$empty
    printf 'title=%s\ngrid=drawer drawer\ngrid=clear save\n\n' "$target"
    printf 'view=drawer\ndots=%s\n\n' "$dots"
    printf 'button=clear\ntitle=Clear\n\n'
    printf 'button=save\ntitle=Save\nshortcut=return\nlook=strong\nclose=true\n'
    ;;
  drawer)
    [ -n "$target" ] && [ ${#2} -eq 81 ] || exit 0
    printf '%s' "$2" > "$data/$name.draft"
    ;;
  clear)
    [ -n "$target" ] && printf '%s' "$empty" > "$data/$name.draft"
    ;;
  save)
    [ -n "$target" ] || exit 0
    dots=$(cat "$data/$name.draft" 2>/dev/null || cat "$data/$name.dots" 2>/dev/null)
    [ ${#dots} -eq 81 ] && [ "$dots" != "$empty" ] || { reset; exit 0; }
    rm -f "$data/$name".*.svg "$data/$name".*.picture.* "$data/$name.draft"
    printf '%s' "$dots" > "$data/$name.dots"
    file="$data/$name.$(date +%s).svg"
    picture "$dots" > "$file"
    openspot setting set --spot "$target" icon "$file"
    ;;
esac
