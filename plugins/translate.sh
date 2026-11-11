#!/bin/sh
# icon=translate
# detail=Between languages
# shortcut=t
# size=small
# read=sheet
. "$OPENSPOT_SH"
export LC_ALL=en_US.UTF-8

saved="$OPENSPOT_DATA/translate"
known="$OPENSPOT_DATA/translate-languages"
settings='x-apple.systempreferences:com.apple.Localization-Settings.extension'

# Prints a field of a block, as it is written, from the lines given.
field() {
  printf '%s\n' "$2" | sed -n "s/^$1=//p" | head -n 1
}

# Keeps the list of languages, so that only the first read asks macOS.
languages() {
  [ -s "$known" ] && return
  trap 'rm -f "$known.$$"; exit 143' TERM
  openspot translate languages > "$known.$$" 2>/dev/null && mv "$known.$$" "$known"
  trap - TERM
  rm -f "$known.$$"
}

# Prints the name of a language.
name() {
  [ -s "$known" ] && awk -v code="$1" -F= '$1 == "language" { found = $2 == code } $1 == "name" && found { print $2; exit }' "$known"
}

# Prints the options of a language menu.
options() {
  if [ -s "$known" ]; then
    awk -F= '$1 == "language" { code = $2 } $1 == "name" { print "option=" code ":" $2 }' "$known"
  else
    printf 'option=en:English\n'
  fi
}

# Prints the first preferred language that is not this one.
preferred() {
  [ -s "$known" ] && awk -v skip="$1" -F= '$1 == "preferred" && $2 != skip { print $2; exit }' "$known"
}

save() {
  printf 'source=%s\ntarget=%s\n' "$source" "$target" > "$saved.$$" && mv "$saved.$$" "$saved"
}

# Asks for the translation of the input. A failure leaves its message in `failure`.
ask() {
  answer=$(printf %s "$input" | openspot translate --from "$source" --to "$target" 2>&1) && return
  failure=$answer
  answer=
  return 1
}

# Translates the input. Text that is already in the target moves the target.
translate() {
  output=
  status=
  answer=
  [ -n "$input" ] || return
  ask || { status=failed; return; }
  status=$(field status "$answer")
  detected=$(field from "$answer")
  if [ "$source" = auto ] && [ "$detected" = "$target" ]; then
    target=$(preferred "$detected")
    : "${target:=en}"
    ask || { status=failed; return; }
    status=$(field status "$answer")
  fi
  output=$(field text "$answer")
}

# Prints the whole sheet.
show() {
  auto="Automatic"
  [ -n "$detected" ] && auto="Auto ($(name "$detected"))"

  case "$status" in
    missing) notice="$(name "$(field from "$answer")") to $(name "$target") is not installed" ;;
    unsupported) notice="macOS cannot translate between these languages" ;;
    unknown) notice="Choose the language of this text" ;;
    failed) notice=${failure:-Could not translate this text} ;;
    *) notice= ;;
  esac
  [ -z "$notice" ] || output=$(esc "$notice")
  corner=.
  if [ "$status" = missing ]; then
    corner=settings
  elif [ -n "$output" ] && [ -z "$notice" ]; then
    corner=copy
  fi

  printf 'grid=source source . .\ngrid=input input input input\ngrid=input input input swap\ngrid=- - - swap\n'
  printf 'grid=target target . swap\ngrid=output output output output\ngrid=output output output %s\n' "$corner"
  printf 'card=source input target output\n\n'

  printf 'choice=source\noption=auto:%s\n' "$auto"
  options
  printf 'value=%s\n\n' "$source"

  printf 'field=input\nvalue=%s\nplaceholder=Type or paste text\n\n' "$(esc "$input")"

  printf 'choice=target\n'
  options
  printf 'value=%s\n\n' "$target"

  printf 'field=output\nvalue=%s\nplaceholder=Translation\nreadonly=true\n\n' "$output"

  printf 'button=swap\nicon=arrow.up.arrow.down\nshortcut=cmd+shift+s\n\n'

  if [ "$corner" = settings ]; then
    printf 'button=settings\nalign=right\nlook=chip\ntitle=Open Settings\n'
  elif [ "$corner" = copy ]; then
    printf 'button=copy\nalign=right\nlook=chip\ntitle=Copy\nshortcut=cmd+return\nclose=true\n'
  fi
}

input=$(value input; printf x)
input=${input%x}
source=$(value source)
target=$(value target)
[ -n "$source" ] || source=$(field source "$(cat "$saved" 2>/dev/null)")
[ -n "$target" ] || target=$(field target "$(cat "$saved" 2>/dev/null)")
if [ ! -s "$known" ] && { [ "$1" = read ] || [ -z "$1" ]; }; then
  (source=${source:-auto}; target=${target:-en}; output=; status=; detected=; show)
  printf -- '---\n'
fi
languages
: "${source:=auto}"
: "${target:=$(preferred "")}"
: "${target:=en}"
output=
answer=
detected=
status=
failure=

case "$1" in
  settings)
    open "$settings"
    ;;
  copy)
    value output | pbcopy
    printf 'toast=Copied\n'
    ;;
  swap)
    translate
    old=$source
    [ "$old" != auto ] || old=$detected
    if [ -n "$old" ]; then
      if [ -n "$output" ]; then
        input=$(printf '%b' "$output"; printf x)
        input=${input%x}
      fi
      source=$target
      target=$old
      save
    fi
    translate
    show
    ;;
  source | target)
    save
    translate
    show
    ;;
  *)
    translate
    show
    ;;
esac
