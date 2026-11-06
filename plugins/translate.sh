#!/bin/sh
# symbol=translate
# subtitle=Between languages
# key=t
# size=small
# order=-1
# stay=true
export LC_ALL=en_US.UTF-8

saved="$OPENSPOT_DATA/translate"
known="$OPENSPOT_DATA/translate-languages"
settings='x-apple.systempreferences:com.apple.Localization-Settings.extension'

# Prints a value of a block, as it is written, from the lines on stdin.
value() {
  printf '%s\n' "$2" | sed -n "s/^$1=//p" | head -n 1
}

# Keeps the list of languages, so that only the first read asks macOS.
languages() {
  [ -s "$known" ] && return
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

save() {
  printf 'source=%s\ntarget=%s\n' "$source" "$target" > "$saved"
}

# Asks the translator that stays running, so that a language stays loaded between texts.
ask() {
  printf 'text=%s\nfrom=%s\nto=%s\n\n' "$input" "$source" "$target" >&3 || { answer=; return 1; }
  answer=
  while IFS= read -r line <&4; do
    [ "$line" = --- ] && return 0
    answer="$answer$line
"
  done
  return 1
}

# Asks for the translation of the input.
translate() {
  output=
  status=
  answer=
  [ -n "$input" ] || return
  ask || { status=failed; return; }
  status=$(value status "$answer")
  detected=$(value from "$answer")
  if [ "$source" = auto ] && [ "$detected" = "$target" ]; then
    target=$(preferred "$detected")
    : "${target:=en}"
    ask || { status=failed; return; }
    status=$(value status "$answer")
  fi
  output=$(value text "$answer")
}

# Prints the whole sheet as one frame.
show() {
  auto="Automatic"
  [ -n "$detected" ] && auto="Auto ($(name "$detected"))"

  printf 'layout=pair\n\n'

  printf 'part=source\ncell=from\noption=auto:%s\n' "$auto"
  options
  printf 'value=%s\n\n' "$source"

  printf 'part=input\ncell=top\ntext=%s\nplaceholder=Type or paste text\n\n' "$input"

  printf 'part=target\ncell=to\n'
  options
  printf 'value=%s\n\n' "$target"

  case "$status" in
    missing) notice="$(name "$(value from "$answer")") to $(name "$target") is not installed" ;;
    unsupported) notice="macOS cannot translate between these languages" ;;
    unknown) notice="Choose the language of this text" ;;
    failed) notice="Could not translate this text" ;;
    *) notice= ;;
  esac

  printf 'part=output\ncell=bottom\ntext=%s\nplaceholder=Translation\nreadonly=true\n\n' "${notice:-$output}"

  printf 'part=swap\ncell=swap\npress=arrow.up.arrow.down\nkey=cmd+shift+s\n\n'

  if [ "$status" = missing ]; then
    printf 'part=settings\ncell=action\nalign=right\nlook=chip\ntitle=Open Settings\npress=true\n'
  elif [ -n "$output" ]; then
    printf 'part=copy\ncell=action\nalign=right\nlook=chip\ntitle=Copy\npress=true\nkey=cmd+return\nclose=true\n'
  fi
  printf -- '---\n'
}

# Does one call, and answers with a frame when the sheet changes.
handle() {
  case "$call" in
    settings)
      open "$settings"
      ;;
    copy)
      printf '%b' "$output" | pbcopy
      printf 'toast=Copied\n---\n'
      ;;
    swap)
      old=$source
      if [ "$old" = auto ]; then
        ask && old=$(value from "$answer")
      fi
      if [ -n "$old" ] && [ "$old" != auto ]; then
        source=$target
        target=$old
        [ -n "$output" ] && input=$output
        save
      fi
      translate
      show
      ;;
    source)
      source=$text
      save
      translate
      show
      ;;
    target)
      target=$text
      save
      translate
      show
      ;;
    input)
      input=$text
      translate
      show
      ;;
    *)
      show
      ;;
  esac
}

languages
input=
output=
answer=
detected=
status=
source=$(value source "$(cat "$saved" 2>/dev/null)")
target=$(value target "$(cat "$saved" 2>/dev/null)")
: "${source:=auto}"
: "${target:=$(preferred "")}"
: "${target:=en}"

folder=$(mktemp -d "${TMPDIR:-/tmp}/openspot-translate.XXXXXX") || exit 1
mkfifo "$folder/in" "$folder/out"
openspot translate --serve < "$folder/in" > "$folder/out" &
translator=$!
exec 3> "$folder/in" 4< "$folder/out"
trap 'exec 3>&-; kill "$translator" 2>/dev/null; rm -rf "$folder"' EXIT

call=
text=
while IFS= read -r line; do
  case "$line" in
    name=*) call=${line#name=} ;;
    value=*) text=${line#value=} ;;
    '')
      handle
      call=
      text=
      ;;
  esac
done
