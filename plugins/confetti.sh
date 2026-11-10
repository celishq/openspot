#!/bin/sh
# title=Confetti
# icon=party.popper
# detail=Celebrate on each screen
# shortcut=k
# read=launch,panel,sheet
# press=run
dir=$(cd "$(dirname "$0")" && pwd)/confetti
. "$dir/shared.sh"

prompt() {
  cat <<EOF
Make a confetti look for me in Openspot, a Mac app. Start at once, and do not explain this message to me.

1. Ask me two questions together. If you have a tool that asks questions with choices, such as AskUserQuestion in Claude Code, use it. Otherwise ask them in one short message. Use the language I write to you in, or English if I have written nothing yet.
   - "What confetti do you want?" Choices: Hearts, Snow, Stars, Flower petals, and my own words.
   - "What should it be called?" Choices: Name it for me, and my own name.
2. Make the look from my answers. Its title is the name I gave, or a short name you pick from what I described.
3. If you can run commands on this Mac, as Claude Code or Codex can:
   - Save it as $mine/<name>.look. The file name is lowercase letters, digits and dashes, such as hearts. If that file exists, pick another name: never overwrite a file there.
   - Check it with: "$bin" check "$mine/<name>.look". Fix each line it names, and check again until it says the look can play.
   - Play it once with: "$bin" "$mine/<name>.look"
   - Tell me in one line that it is ready in the Look menu of Confetti, and that Return on the Confetti card plays it.
4. If you cannot run commands, as in a chat in the browser: give me the whole file in one code block, and tell me in one line to copy it, open Confetti in Openspot and press ⌘⇧V.

A look file has one key=value on each line:
- title=<its name in the Look menu>
- color=#RRGGBB, one line for each colour. A number after it makes it more or less common, such as color=#6E4604 0.5.
- shape=<shape>, one line for each shape, with a number as for colours. The shapes are rect, square, strip, dot, bead, flag, arc, heart, star and streamer, a long twisted ribbon. Shapes take the colours.
- glyph=<one to three characters>, such as 💖 or 🌸, drawn as they are, with a number as for colours. Use a glyph for a picture that no shape gives.
- finish=flat, paper or foil. Foil is shiny metal. Flat is the default.
- amount=<0.2 to 3>: how many pieces fall. 1 is the default.
- speed=<0.5 to 2>: how fast they fall. 1 is the default.
- size=<0.5 to 3>: how large the pieces are. 1 is the default.

This is the Gold look:

$(cat "$dir/looks/gold.look")
EOF
}

slug() {
  name=$(printf %s "$1" | tr '[:upper:]' '[:lower:]' | LC_ALL=C sed -e 's/[^a-z0-9]/-/g' -e 's/--*/-/g' -e 's/^-//' -e 's/-$//')
  name=${name:-my-look}
  free=$name
  count=2
  while [ -e "$mine/$free.look" ] || [ -e "$dir/looks/$free.look" ]; do
    free="$name-$count"
    count=$((count + 1))
  done
  printf %s "$free"
}

own() {
  [ -f "$mine/$1.look" ] || fail "$(look_title "$1") comes with Openspot, so it cannot change. Make your own with ⌘N."
}

case "$1" in
  read)
    chosen=$(default_look)
    key=$(play_key)
    printf 'grid=look look look look\ngrid=key key key key\ngrid=make make make make\n\n'
    printf 'choice=look\ntitle=Look\n'
    for id in $(look_ids); do printf 'option=%s:%s\n' "$id" "$(esc "$(look_title "$id")")"; done
    printf 'value=%s\n\n' "$chosen"
    printf 'hotkey=key\ntitle=Shortcut\nvalue=%s\n\n' "$key"
    printf 'button=make\ntitle=Make your own with AI\nalign=center\nshortcut=cmd+n\n\n'
    printf 'button=paste\ntitle=Paste a look from an AI chat\nshortcut=cmd+shift+v\n\n'
    if [ -f "$mine/$chosen.look" ]; then
      printf 'button=rename\ntitle=Rename %s\nshortcut=cmd+r\nform=true\n\n' "$(esc "$(look_title "$chosen")")"
      printf 'button=delete\ntitle=Delete %s\nshortcut=cmd+backspace\nconfirm=Press again to move it to the Trash\n\n' "$(esc "$(look_title "$chosen")")"
    fi
    printf 'button=mine\ntitle=Show my looks in Finder\nshortcut=cmd+o\n'
    [ -z "${OPENSPOT_REASON-}" ] || (listen > /dev/null 2>&1 &)
    ;;
  run | play)
    play "$(default_look)"
    ;;
  look)
    play "$2" quiet
    set_default "$2"
    ;;
  key)
    old=$(play_key)
    if app_key "$2"; then
      fail "$(key_name "$2") belongs to the apps on your Mac, such as Copy or Paste. Hold ⌃ or ⌥ with a letter. $(key_name "$old") still plays it."
    fi
    printf %s "$2" > "$data/key.$$" && mv "$data/key.$$" "$data/key"
    if ! listen; then
      reason=$(tail -n 1 "$data/listen.log" 2>/dev/null)
      printf %s "$old" > "$data/key.$$" && mv "$data/key.$$" "$data/key"
      listen > /dev/null 2>&1
      fail "${reason:-Openspot cannot use that key.} $(key_name "$old") still plays it."
    fi
    printf 'toast=%s\n' "$(esc "$(key_name "$2") now plays confetti anywhere.")"
    ;;
  make)
    build quiet || fail "Openspot cannot build the confetti: $(grep -m 1 error: "$data/build.log"). Install the Command Line Tools with \`xcode-select --install\`."
    mkdir -p "$mine"
    prompt | pbcopy
    printf 'toast=%s\n' "$(esc 'Copied. Paste it into your AI and press Return.')"
    ;;
  paste)
    build quiet || fail "Openspot cannot build the confetti: $(grep -m 1 error: "$data/build.log"). Install the Command Line Tools with \`xcode-select --install\`."
    mkdir -p "$mine"
    draft="$mine/.paste.$$"
    pbpaste | grep -v '^[[:space:]]*```' > "$draft"
    fault=$("$bin" check "$draft" 2>&1 >/dev/null | head -n 1)
    if [ -n "$fault" ]; then
      rm -f "$draft"
      pbpaste | grep -q '=' || fail "The clipboard holds no look. Copy the whole file your AI gave, then press ⌘⇧V again."
      fail "This look cannot play. $fault Ask your AI to fix it, then copy it again."
    fi
    title=$(sed -n 's/^title=//p' "$draft" | head -n 1)
    id=$(slug "${title:-My look}")
    mv "$draft" "$mine/$id.look"
    play "$id" quiet
    set_default "$id"
    printf 'toast=%s\n' "$(esc "Added $(look_title "$id"). $(key_name "$(play_key)") plays it now.")"
    ;;
  rename)
    id=$(default_look)
    own "$id"
    name=$(value name)
    if [ -z "$name" ]; then
      printf 'title=Rename\n\nfield=name\ntitle=Name\ntext=%s\n' "$(esc "$(look_title "$id")")"
      exit 0
    fi
    file="$mine/$id.look"
    { printf 'title=%s\n' "$(printf %s "$name" | tr -d '\n')"; grep -v '^title=' "$file"; } > "$file.$$" && mv "$file.$$" "$file" || fail "Openspot cannot rename it, so it keeps its name."
    ;;
  delete)
    id=$(default_look)
    own "$id"
    title=$(look_title "$id")
    mv "$mine/$id.look" "$HOME/.Trash/$id-$(date +%s).look" || fail "Openspot cannot move $title to the Trash, so it stays."
    printf 'toast=%s\n' "$(esc "Moved $title to the Trash. Colorful plays now.")"
    ;;
  mine)
    mkdir -p "$mine"
    open "$mine"
    ;;
esac
