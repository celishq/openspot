#!/bin/sh
. "$OPENSPOT_SH"

# The Settings window. Its view, settings.swift, draws every page from the records that `window` prints, and each click
# sends back one line of words split by tabs, such as `set<tab>notes<tab>open<tab>ctrl+n`, which `act` runs.

tab=$(printf '\t')

# Shows a toast of the last line of a text, such as what a failed `openspot` call said.
toast() {
  openspot toast "$(printf '%s\n' "$1" | tail -n 1)"
}

# Runs an `openspot` call, and shows why in a toast when it fails.
call() {
  said=$(openspot "$@" 2>&1) || toast "$said"
}

# Prints each record of stdin that has an item, except a spot of the app itself, as an item of the hidden list with its
# id after $1 and kind=$2. A record that holds the line $3 is left out.
records() {
  awk -v prefix="$1" -v kind="$2" -v skip="${3-}" 'BEGIN { RS = ""; FS = "\n" }
    { id = ""; rest = ""
      for (i = 1; i <= NF; i++) {
        if ($i == skip) next
        if (index($i, "item=") == 1) id = substr($i, 6); else rest = rest $i "\n"
      }
      if (id == "" || index(id, "openspot/") == 1 && kind == "spot") next
      printf "\nitem=%s%s\nparent=rows\nkind=%s\n%s", prefix, id, kind, rest }'
}

# Prints the window: the view's block, with where to land when the show was asked to, then every access, spot, setting
# row, theme, the account and the guided grant that runs as items.
window() {
  printf 'frame=\n\nsettings=window\n'
  [ -z "${1-}" ] || printf 'at=%s\n' "$1"
  printf '\nitems=rows\nclass=hidden\n'
  openspot access list | records access: access
  openspot spot list | records spot: spot
  openspot spot list --core | records spot: spot on=true
  openspot setting list | sed 's/^kind=/form=/' | records row: row
  openspot theme list | records theme: theme
  openspot account show 2>/dev/null | records '' account
  openspot access grant | records '' grant
}

# Prints the System Settings pane of the macOS access $1.
pane() {
  case $1 in
    accessibility) echo Privacy_Accessibility ;;
    automation) echo Privacy_Automation ;;
    screen) echo Privacy_ScreenCapture ;;
    calendars) echo Privacy_Calendars ;;
    reminders) echo Privacy_Reminders ;;
    camera) echo Privacy_Camera ;;
    microphone) echo Privacy_Microphone ;;
    input) echo Privacy_ListenEvent ;;
  esac
}

# Asks macOS for the access $1: Accessibility by its own prompt, the keep-awake helper in Login Items, the others in
# their pane of System Settings.
ask() {
  case $1 in
    accessibility) call access ask accessibility ;;
    helper) open 'x-apple.systempreferences:com.apple.LoginItems-Settings.extension' ;;
    *) open "x-apple.systempreferences:com.apple.preference.security?$(pane "$1")" ;;
  esac
}

# Runs the words that a click of the view sent.
act() {
  IFS=$tab read -r verb one two three <<EOF
$1
EOF
  case $verb in
    set) if [ -n "$three" ]; then call setting set --spot "$one" "$two" "$three"; else call setting set --spot "$one" "$two"; fi ;;
    say) toast "$one" ;;
    remove) call setting remove --spot "$one" "$two" ;;
    turn) call setting set --spot "$one" enabled "$two" ;;
    theme) call theme use "$one" ;;
    ask) ask "$one" ;;
    pane) if [ "$one" = helper ]; then ask helper; else open "x-apple.systempreferences:com.apple.preference.security?$(pane "$one")"; fi ;;
    allow) call spot allow "$one" ;;
    review) if [ -n "$two" ]; then call spot allow "$one" "$two"; else call spot allow "$one"; fi ;;
    grant) call access grant --end ;;
    restart) call app restart ;;
    *) echo 'Settings cannot do that.' >&2; exit 1 ;;
  esac
}

case "$1" in
  show) window "$(value at)" ;;
  window)
    act "$(value value)"
    window
    ;;
  *)
    echo 'Settings cannot do that.' >&2
    exit 1
    ;;
esac
