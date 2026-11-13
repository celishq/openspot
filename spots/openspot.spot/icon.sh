#!/bin/sh
# title=Icon
# icon=paintbrush.pointed
# detail=Draw the icon of a spot
# on=sheet.open
# view=icon.swift
# uses=spots
# offers=float
#
# button=change
# title=Change Icon
# offers=actions
data="$OPENSPOT_DATA/icons"
target=$(cat "$data/target" 2>/dev/null)
name=$(printf '%s' "$target" | tr '/' '_')

# Prints an SVG of 16 by 16 round dots from 256 palette characters, where a dot is a digit and an empty place is a dot.
picture() {
  printf '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 16 16">'
  printf '%s\n' "$1" | fold -w 1 | awk '
    BEGIN { split("#1D1D1F #F5F5F7 #FF4A1C #FFC400 #34C759 #0A84FF", colour, " ") }
    $0 ~ /[0-5]/ { printf "<circle cx=\"%.1f\" cy=\"%.1f\" r=\"0.42\" fill=\"%s\"/>", (NR - 1) % 16 + 0.5, int((NR - 1) / 16) + 0.5, colour[$0 + 1] }'
  printf '</svg>\n'
}

case "$1" in
  change)
    mkdir -p "$data"
    printf '%s' "$2" > "$data/target"
    openspot spot float "$OPENSPOT_ID"
    ;;
  read)
    [ -n "$target" ] || { printf 'text=none\ntitle=No spot\ndetail=Choose Change Icon in the menu of a card\n'; exit 0; }
    dots=$(cat "$data/$name.dots" 2>/dev/null)
    [ ${#dots} -eq 256 ] || dots=$(printf '%256s' '' | tr ' ' '.')
    printf 'title=%s\n\nview=drawer\ntarget=%s\ndots=%s\n' "$target" "$target" "$dots"
    ;;
  drawer)
    [ -n "$target" ] || exit 0
    rm -f "$data/$name".*.svg
    case "$2" in
      reset)
        rm -f "$data/$name.dots"
        openspot setting set --spot "$target" icon
        ;;
      save\ *)
        dots=${2#save }
        [ ${#dots} -eq 256 ] || { echo "The drawing needs 256 dots." >&2; exit 1; }
        printf '%s' "$dots" > "$data/$name.dots"
        file="$data/$name.$(date +%s).svg"
        picture "$dots" > "$file"
        openspot setting set --spot "$target" icon "$file"
        ;;
    esac
    ;;
esac
