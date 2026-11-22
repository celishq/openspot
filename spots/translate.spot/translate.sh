#!/bin/sh
. "$OPENSPOT_SH"
export LC_ALL=en_US.UTF-8

saved="$OPENSPOT_DATA/translate"
known="$OPENSPOT_DATA/languages"
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
  [ -s "$known" ] && awk -v code="$1" -F= '$1 == "item" { found = $2 == code } $1 == "title" && found { print $2; exit }' "$known"
}

# Prints the options of a language menu, each as a block.
options() {
  if [ -s "$known" ]; then
    awk -F= '$1 == "item" { code = $2 } $1 == "title" { print ""; print "option=" code; print "title=" $2 }' "$known"
  else
    printf '\noption=en\ntitle=English\n'
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
  answer=$(printf %s "$input" | openspot translate text --from "$source" --to "$target" 2>&1) && return
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

  printf 'frame=\nclass=gap-part\n\n'

  printf 'box=pair\nclass=relative grow gap-part\n\nbox=top\nparent=pair\nclass=grow gap-part\n\n'

  printf 'choice=source\nparent=top\nclass=self-start\nvalue=%s\n\noption=auto\ntitle=%s\n' "$source" "$auto"
  options
  printf '\n'

  printf 'box=text\nparent=top\nclass=relative grow\n\n'
  printf 'field=input\nparent=text\nclass=absolute inset-0\ntype=multiline\nplaceholder=Type or paste text\n'
  openspot_kv value "$input"
  printf '\n'

  printf 'box=seam\nparent=pair\nclass=absolute inset-0 justify-center items-end pr-2\n\n'
  printf 'button=swap\nparent=seam\nclass=backdrop-blur rounded-full\nicon=arrow.up.arrow.down\nshortcut=cmd+shift+s\nclose=false\n\n'

  printf 'box=bottom\nparent=pair\nclass=grow gap-part\n\n'

  printf 'choice=target\nparent=bottom\nclass=self-start\nvalue=%s\n' "$target"
  options
  printf '\n'

  printf 'box=result\nparent=bottom\nclass=relative grow\n\n'
  printf 'field=output\nparent=result\nclass=absolute inset-0\ntype=multiline\nvalue=%s\nplaceholder=Translation\nreadonly=true\n\n' "$output"
  printf 'box=corner\nparent=result\nclass=absolute inset-0 justify-end items-end p-2\n\n'

  if [ "$corner" = settings ]; then
    printf 'button=settings\nparent=corner\nclass=rounded-full\ntitle=Open Settings\n'
  elif [ "$corner" = copy ]; then
    printf 'button=copy\nparent=corner\nclass=rounded-full\ntitle=Copy\nshortcut=cmd+return\n'
  fi
}

input=$(value input.input; printf x)
input=${input%x}
typed=$(value search)
[ -z "$typed" ] || input=$typed
source=$(value input.source)
target=$(value input.target)
[ -n "$source" ] || source=$(field source "$(cat "$saved" 2>/dev/null)")
[ -n "$target" ] || target=$(field target "$(cat "$saved" 2>/dev/null)")
if [ ! -s "$known" ] && { [ "$1" = show ] || [ -z "$1" ]; }; then
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
    value input.output | openspot clipboard copy
    openspot toast Copied
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
