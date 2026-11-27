# The build of New spot: it runs an agent with no window and tells the sheet each step, or hands the words to an
# agent in a terminal or an app. new.sh sources it.

# Prints one step of the agent, from a tool it uses, in plain words.
step() {
  case $1 in
    Write) printf 'Writing %s' "${2##*/}" ;;
    Edit | MultiEdit) printf 'Changing %s' "${2##*/}" ;;
    Read) printf 'Reading %s' "${2##*/}" ;;
    Glob | Grep) printf 'Looking through the files' ;;
    Bash)
      case $2 in
        *' guide'*) printf 'Reading the guide' ;;
        *' check'*) printf 'Checking the spot' ;;
        *' spot run'*) printf 'Trying the spot' ;;
        *' render'*) printf 'Looking at its card' ;;
        *' spot show'*) printf 'Looking at what it runs' ;;
        *chmod*) printf 'Making it run' ;;
        *) printf 'Running a command' ;;
      esac
      ;;
    *) printf 'Working' ;;
  esac
}

# Tells the sheet that a build moved, so that it shows the new step.
moved() {
  openspot emit step build="$1" > /dev/null 2>&1 || true
}

# Prints a frame that says how far the run is and its step, which the card of New spot shows, and shows the step in
# the build's toast, which stays until the build ends.
progress() {
  # The Edit sheet of a spot hears no step of New spot, so its own run draws it again at each step.
  if [ -n "${OPENSPOT_EDIT-}" ]; then
    sheet ''
    printf -- '---\n'
    return
  fi
  step=$(get "$building" step)
  openspot toast --id "build-$building" "$work ${step:-}" > /dev/null 2>&1 || true
  printf 'frame=\n'
  openspot_kv title "$work"
  openspot_kv detail "$step"
  printf 'progress=%s\n\n---\n' "$1"
}

# Says whether the folder of the spot $1 holds a script: a file that runs, or a .js file.
has_script() {
  find "$folder/$1.spot" -maxdepth 1 -type f \( -perm -u+x -o -name '*.js' \) 2>/dev/null | grep -q .
}

# Takes the draft off the spot of the new build $1, and puts the spot at the top of the grid.
publish() {
  [ -z "$was" ] || return 0
  made=$(get "$1" spot)
  sed -i '' -E "/^state *= *[\"']draft[\"']/d" "$folder/$made.spot/spot.toml"
  openspot grid push "$made" > /dev/null 2>&1 || true
}

# Runs the agent $3 with no window for the build $1, with the prompt $4. Each step goes to the build's files and tells
# the sheet. The run prints its title, its step and its progress, which the card of New spot shows.
run() {
  building=$1
  bin=$(agent_bin "$3") || { echo "Openspot cannot find $3." >&2; exit 1; }
  mkdir -p "$folder" "${builds:?}/$1"
  log="$builds/$1/log"
  name=$(get "$1" spot)
  if [ -n "$(get "$1" change)" ]; then work="Changing $name…"; else work='Building a spot…'; fi
  put "$1" pid "$$"
  put "$1" state running
  trap 'openspot toast --remove "build-$building" > /dev/null 2>&1; put "$building" state stopped; moved "$building"; exit 0' TERM INT
  put "$1" step 'Starting the agent…'
  put "$1" said ''
  put "$1" end ''
  progress 0.03
  moved "$1"
  session=$(get "$1" session)
  openspot=$(command -v openspot)
  cd "$folder" || exit 1
  case $3 in
    claude)
      "$bin" -p "$4" ${session:+--resume "$session"} --output-format stream-json --verbose --permission-mode acceptEdits --add-dir "$folder" \
        --allowedTools Read Write Edit Glob Grep "Bash($openspot:*)" "Bash(\"$openspot\":*)" "Bash(openspot:*)" \
        "Bash(chmod:*)" "Bash(mkdir:*)" "Bash(ls:*)" "Bash(cat:*)" "Bash(swift:*)" "Bash(swiftc:*)" < /dev/null 2> "$log" |
        /usr/bin/jq -r --unbuffered 'if .type == "assistant" then (.message.content[]? | if .type == "text" then "say\t" + (.text | gsub("[\n\t]"; " ")) elif .type == "tool_use" then "tool\t" + .name + "\t" + ((.input.file_path // .input.command // "") | tostring | gsub("[\n\t]"; " ")) else empty end) elif .type == "result" then "end\t" + (.session_id // "") + "\t" + ((.is_error // false) | tostring) + "\t" + ((.result // "") | gsub("[\n\t]"; " ")) else empty end' 2>> "$log" |
        {
          fill=3
          while IFS='	' read -r kind one two three; do
            case $kind in
              say) put "$1" said "$(printf '%s' "$one" | cut -c 1-160)" ;;
              tool)
                put "$1" step "$(step "$one" "$two")"
                ;;
              end) put "$1" end "$(printf '%s\t%s\t%s' "$one" "$two" "$three")"; continue ;;
            esac
            [ "$fill" -ge 90 ] || fill=$((fill + 4))
            progress "0.$(printf '%02d' "$fill")"
            moved "$1"
          done
        }
      ;;
    codex)
      "$bin" exec --full-auto -C "$folder" "$4" < /dev/null > "$log" 2>&1 && put "$1" end "$(printf '\tfalse\t')"
      ;;
  esac
  IFS='	' read -r session failed said <<END
$(get "$1" end)
END
  name=$(get "$1" spot)
  if [ -z "$failed" ] || [ "$failed" = true ] || ! has_script "$name"; then
    [ -n "$said" ] || said=$(tail -n 1 "$log")
    has_script "$name" || [ "$failed" = true ] || said='The agent is done, but made no spot.'
    openspot toast --remove "build-$1" > /dev/null 2>&1 || true
    put "$1" state failed
    put "$1" said "${said:-The agent gave no answer.}"
    moved "$1"
    [ -z "${OPENSPOT_EDIT-}" ] || { sheet ''; printf -- '---\n'; }
    echo "The agent stopped: ${said:-it gave no answer}." >&2
    exit 1
  fi
  [ -z "$session" ] || put "$1" session "$session"
  # The build is done before its spot shows, so that the spot never comes while New spot still shows it as building.
  rm -f "$builds/$1/fresh"
  put "$1" state ready
  moved "$1"
  publish "$1"
  shown "$1" "$name"
  [ -z "${OPENSPOT_EDIT-}" ] || sheet ''
}

# Says that the spot $2 of the build $1 is ready. It waits at the top of the grid, marked New, and opens only when people
# open it, so that nothing takes the panel.
shown() {
  openspot toast --remove "build-$1" > /dev/null 2>&1 || true
  openspot toast "$2 is ready." > /dev/null 2>&1 || true
}

# Stops the run of the build $1: its group when the run leads one, or else the run and its children.
stop() {
  pid=$(get "$1" pid)
  if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
    group=$(ps -o pgid= -p "$pid" | tr -d ' ')
    if [ "$group" = "$pid" ]; then
      kill -TERM -- "-$pid" 2>/dev/null
    else
      pkill -TERM -P "$pid" 2>/dev/null
      kill -TERM "$pid" 2>/dev/null
    fi
    tries=0
    while kill -0 "$pid" 2>/dev/null && [ "$tries" -lt 30 ]; do
      sleep 0.1
      tries=$((tries + 1))
    done
  fi
  settle "$1"
}

# Opens a new tab of the terminal $2 that runs the agent $1 in the spots folder, with the prompt as its first message.
terminal() {
  bin=$(agent_bin "$1") || { echo "Openspot cannot find $1." >&2; exit 1; }
  mkdir -p "$folder" "$OPENSPOT_DATA/terminal"
  stamp=$(date +%s)
  printf '%s' "$3" > "$OPENSPOT_DATA/terminal/$stamp.prompt"
  session=
  [ -z "$job" ] || [ "$1" != claude ] || session=$(get "$job" session)
  {
    printf '#!/bin/zsh -l\ncd %s || exit 1\n' "$(quote "$folder")"
    printf 'exec %s %s"$(cat %s)"\n' "$(quote "$bin")" "${session:+--resume $session }" "$(quote "$OPENSPOT_DATA/terminal/$stamp.prompt")"
  } > "$OPENSPOT_DATA/terminal/$stamp.command"
  chmod +x "$OPENSPOT_DATA/terminal/$stamp.command"
  case $2 in
    Ghostty) open -na Ghostty --args -e "$OPENSPOT_DATA/terminal/$stamp.command" ;;
    *) open -a "$2" "$OPENSPOT_DATA/terminal/$stamp.command" ;;
  esac || { echo "Openspot cannot open $2." >&2; exit 1; }
}

# Prints $1 with each byte as %XX, for a link.
encoded() {
  printf '%s' "$1" | LC_ALL=C od -An -tx1 -v | tr -d ' \n' | sed 's/../%&/g'
}

# Prints the bundle id of the app in front.
front() {
  lsappinfo info -only bundleid "$(lsappinfo front)" 2>/dev/null | sed -n 's/.*="\(.*\)"/\1/p'
}

# Waits until the app at $1 is in front, for ten seconds at most, then a moment more for its new session to show. Fails
# when another app is in front by then, so that no key lands in it.
await_front() {
  id=$(plutil -extract CFBundleIdentifier raw "$1/Contents/Info.plist" 2>/dev/null)
  tries=0
  while [ "$(front)" != "$id" ] && [ $tries -lt 50 ]; do
    sleep 0.2
    tries=$((tries + 1))
  done
  sleep 1.5
  [ "$(front)" = "$id" ]
}

# Starts a new session of the agent in the app at $2, the place $1, in the spots folder, and sends it the words $3. The
# Claude, Codex and an editor with Claude Code open the session by a link; another app opens a new chat with ⌘N.
in_app() {
  mkdir -p "$folder"
  name=$(basename "$2" .app)
  # Each app takes the prompt in a link, so nothing is pasted and no Accessibility is asked. A link only fills the box,
  # and the person presses Return. The link names no folder, as a launcher does: Claude and ChatGPT ask to trust the
  # folder of every link that names one, so the session opens in the folder the person last chose, and the prompt
  # names the spots folder by its whole path.
  prompt=$(encoded "$3")
  case $1 in
    app-claude) open "claude://code/new?q=$prompt" ;;
    app-codex) open "codex://new?prompt=$prompt" ;;
    app-vscode | app-cursor | app-windsurf) open -a "$2" "$folder" && open "${1#app-}://anthropic.claude-code/open?prompt=$prompt" ;;
    *) false ;;
  esac || { echo "Openspot cannot open $name." >&2; exit 1; }
  openspot toast "Press Return in $name to start."
}

# Prints a word between single quotes for a shell script.
quote() {
  printf "'%s'" "$(printf '%s' "$1" | sed "s/'/'\\\\''/g")"
}
