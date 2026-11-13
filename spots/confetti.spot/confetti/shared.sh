# The looks, the default look, the build and the launch of the confetti, which confetti.sh beside this folder loads.
. "$OPENSPOT_SH"

data=${OPENSPOT_DATA:?}
bin="$data/confetti"
src="$dir/confetti.swift"
mine="$data/looks"

look_ids() {
  seen=' '
  for file in "$dir"/looks/*.look "$mine"/*.look; do
    [ -f "$file" ] || continue
    id=${file##*/}
    id=${id%.look}
    case $seen in *" $id "*) continue ;; esac
    seen="$seen$id "
    printf '%s\n' "$id"
  done
}

look_file() {
  if [ -f "$mine/$1.look" ]; then printf %s "$mine/$1.look"; else printf %s "$dir/looks/$1.look"; fi
}

look_title() {
  title=
  while IFS= read -r line || [ -n "$line" ]; do
    case $line in title=*) title=${line#title=}; break ;; esac
  done < "$(look_file "$1")"
  printf %s "${title:-$1}"
}

default_look() {
  look=
  { read -r look < "$data/default"; } 2>/dev/null
  if [ -n "$look" ] && [ -f "$(look_file "$look")" ]; then printf %s "$look"; else printf colorful; fi
}

set_default() {
  [ -f "$(look_file "$1")" ] || return 0
  printf %s "$1" > "$data/default.$$" && mv "$data/default.$$" "$data/default"
}

build() {
  [ -x "$bin" ] && [ "$bin" -nt "$src" ] && return 0
  [ "${1-}" = quiet ] || printf 'title=Building the confetti\ndetail=A few seconds, once\n---\n'
  /usr/bin/xcrun swiftc -O -o "$bin.new" "$src" 2> "$data/build.log" && mv "$bin.new" "$bin"
}

fail() {
  printf 'toast=%s\n' "$(esc "$1")"
  exit 1
}

play() {
  build "${2-}" || fail "Openspot cannot build the confetti: $(grep -m 1 error: "$data/build.log"). Install the Command Line Tools with \`xcode-select --install\`."
  file=$(look_file "$1")
  fault=$("$bin" check "$file" 2>&1 >/dev/null | head -n 1)
  [ -z "$fault" ] || fail "$(look_title "$1") cannot play. $fault"
  if [ "${2-}" = quiet ]; then
    kill "$(cat "$data/playing" 2>/dev/null)" 2>/dev/null
  fi
  nohup "$bin" "$file" > /dev/null 2>&1 &
  printf %s "$!" > "$data/playing"
}

key_name() {
  printf %s "$1" | awk -F+ '{
    out = ""
    for (i = 1; i < NF; i++) {
      if ($i == "ctrl" || $i == "control") out = out "⌃"
      else if ($i == "option" || $i == "opt" || $i == "alt") out = out "⌥"
      else if ($i == "shift") out = out "⇧"
      else if ($i == "cmd" || $i == "command") out = out "⌘"
    }
    printf "%s%s", out, toupper($NF)
  }'
}

app_key() {
  case "+${1%+*}+" in
    *+ctrl+*|*+control+*|*+option+*|*+opt+*|*+alt+*) return 1 ;;
    *+cmd+*|*+command+*) return 0 ;;
    *) return 1 ;;
  esac
}

play_key() {
  [ -f "$data/key" ] || printf option+c > "$data/key"
  key=
  read -r key < "$data/key"
  printf %s "$key"
}

listening() {
  pid=
  { read -r pid < "$data/listen.pid"; } 2>/dev/null
  [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null
}

listen() {
  build quiet || return 1
  key=$(play_key)
  if listening && [ "$data/listen.pid" -nt "$bin" ] && [ "$data/listen.pid" -nt "$data/key" ]; then return 0; fi
  listening && kill "$pid"
  rm -f "$data/listen.pid"
  [ -n "$key" ] || return 0
  nohup "$bin" listen "$key" "$data" "$dir/looks" "$PPID" > "$data/listen.log" 2>&1 &
  printf %s "$!" > "$data/listen.pid"
  sleep 0.3
  listening
}
