#!/bin/sh
# symbol=translate
# subtitle=Between languages
# key=t
# size=small
# order=-1
# read=open
export LC_ALL=en_US.UTF-8

data="${OPENSPOT_CONFIG:-$HOME/.config/openspot}/data"
saved="$data/translate"
known="$data/translate-languages"
settings='x-apple.systempreferences:com.apple.Localization-Settings.extension'

values=$(cat)

# Prints a value of a block, as it is written, from the lines on stdin.
value() {
  printf '%s\n' "$2" | sed -n "s/^$1=//p" | head -n 1
}

# Keeps the list of languages, so that only the first read asks macOS.
languages() {
  [ -s "$known" ] && return
  mkdir -p "$data"
  openspot translate languages > "$known.new" 2>/dev/null && mv "$known.new" "$known"
  rm -f "$known.new"
}

# Prints the name of a language.
name() {
  [ -s "$known" ] && awk -v code="$1" -F= '$1 == "language" { found = $2 == code } $1 == "name" && found { print $2; exit }' "$known"
}

# Prints the options of a language menu.
options() {
  [ -s "$known" ] && awk -F= '$1 == "language" { code = $2 } $1 == "name" { print "option=" code ":" $2 }' "$known"
}

# Prints the first preferred language that is not this one.
preferred() {
  [ -s "$known" ] && awk -v skip="$1" -F= '$1 == "preferred" && $2 != skip { print $2; exit }' "$known"
}

languages
input=$(value input "$values")
output=$(value output "$values")
source=$(value source "$values")
target=$(value target "$values")
: "${source:=$(value source "$(cat "$saved" 2>/dev/null)")}"
: "${target:=$(value target "$(cat "$saved" 2>/dev/null)")}"
: "${source:=auto}"
: "${target:=$(preferred "")}"
: "${target:=en}"
detected=
status=

# Asks macOS for the translation of the input.
translate() {
  output=
  status=
  [ -n "$input" ] || return
  answer=$(printf '%b' "$input" | openspot translate --from "$source" --to "$target") || { status=failed; return; }
  status=$(value status "$answer")
  detected=$(value from "$answer")
  if [ "$source" = auto ] && [ "$detected" = "$target" ]; then
    target=$(preferred "$detected")
    : "${target:=en}"
    answer=$(printf '%b' "$input" | openspot translate --from "$source" --to "$target") || { status=failed; return; }
    status=$(value status "$answer")
  fi
  output=$(value text "$answer")
}

save() {
  mkdir -p "$data"
  printf 'source=%s\ntarget=%s\n' "$source" "$target" > "$saved"
}

case "$1 $2" in
  "press settings")
    open "$settings"
    exit 0
    ;;
  "press copy")
    printf '%b' "$output" | pbcopy
    echo "toast=Copied"
    exit 0
    ;;
  "press swap")
    old=$source
    [ "$old" = auto ] && old=$(value from "$(printf '%b' "$input" | openspot translate --from auto --to "$target")")
    if [ -n "$old" ]; then
      source=$target
      target=$old
      [ -n "$output" ] && input=$output
      save
    fi
    translate
    ;;
  "set source"|"set target")
    save
    translate
    ;;
  "set input")
    translate
    ;;
  *)
    translate
    ;;
esac

auto="Automatic"
[ -n "$detected" ] && auto="Auto ($(name "$detected"))"

printf 'part=source\noption=auto:%s\n' "$auto"
options
printf 'value=%s\n\n' "$source"

printf 'part=input\ntext=%s\nlines=7\nplaceholder=Type or paste text\n\n' "$input"

printf 'section=swap\npress=arrow.up.arrow.down\nkey=cmd+shift+s\n\n'

printf 'part=target\n'
options
printf 'value=%s\n\n' "$target"

case "$status" in
  missing) notice="$(name "$(value from "$answer")") to $(name "$target") is not installed" ;;
  unsupported) notice="macOS cannot translate between these languages" ;;
  unknown) notice="Choose the language of this text" ;;
  failed) notice="Could not translate this text" ;;
  *) notice= ;;
esac

printf 'part=output\ntext=%s\nlines=7\nplaceholder=Translation\nreadonly=true\n\n' "${notice:-$output}"

if [ "$status" = missing ]; then
  printf 'part=settings\ntitle=Open Settings\npress=true\n'
elif [ -n "$output" ]; then
  printf 'part=copy\ntitle=Copy\npress=true\nkey=cmd+return\nclose=true\n'
fi
