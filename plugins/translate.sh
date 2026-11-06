#!/bin/sh
# symbol=translate
# subtitle=Between languages
# key=t
# size=small
# order=-1
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
  openspot translate languages > "$known.$$" 2>/dev/null && mv "$known.$$" "$known"
  rm -f "$known.$$"
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

  printf 'grid=s s . .\ngrid=i i i i\ngrid=i i i x\ngrid=- - - x\ngrid=t t . x\ngrid=o o o o\ngrid=o o o c\ncard=s i t o\n\n'

  printf 'part=source\ncell=s\noption=auto:%s\n' "$auto"
  options
  printf 'value=%s\n\n' "$source"

  printf 'part=input\ncell=i\ntext=%s\nplaceholder=Type or paste text\n\n' "$(esc "$input")"

  printf 'part=target\ncell=t\n'
  options
  printf 'value=%s\n\n' "$target"

  case "$status" in
    missing) notice="$(name "$(field from "$answer")") to $(name "$target") is not installed" ;;
    unsupported) notice="macOS cannot translate between these languages" ;;
    unknown) notice="Choose the language of this text" ;;
    failed) notice=${failure:-Could not translate this text} ;;
    *) notice= ;;
  esac
  [ -z "$notice" ] || output=$(esc "$notice")

  printf 'part=output\ncell=o\ntext=%s\nplaceholder=Translation\nreadonly=true\n\n' "$output"

  printf 'part=swap\ncell=x\npress=arrow.up.arrow.down\nkey=cmd+shift+s\n\n'

  if [ "$status" = missing ]; then
    printf 'part=settings\ncell=c\nalign=right\nlook=chip\ntitle=Open Settings\npress=true\n'
  elif [ -n "$output" ] && [ -z "$notice" ]; then
    printf 'part=copy\ncell=c\nalign=right\nlook=chip\ntitle=Copy\npress=true\nkey=cmd+return\nclose=true\n'
  fi
}

languages
input=$(value input; printf x)
input=${input%x}
source=$(value source)
target=$(value target)
[ -n "$source" ] || source=$(field source "$(cat "$saved" 2>/dev/null)")
[ -n "$target" ] || target=$(field target "$(cat "$saved" 2>/dev/null)")
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
