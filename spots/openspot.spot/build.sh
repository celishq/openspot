# The build of New spot: it runs an agent with no window and tells the sheet each step, or hands the words to an
# agent in a terminal or an app. new.sh sources it.

# Prints the words of the prompt that name the draft folder $1 of a new build.
draft_words() {
  printf 'Build the spot in the folder %s. Its spot.toml says state = "draft", so the spot shows nowhere while you build it: keep that line, and New spot takes it off when you are done.' "$1"
}

# Prints the words of the prompt that ask the agent to report each step of the build $1 with the command $2.
step_words() {
  printf 'Before each step, such as reading the guide, writing a file, checking or rendering the spot, run %s spot run openspot/new step build=%s words="<the step in a few words, such as Writing view.html>" < /dev/null, so that Openspot shows how far you are.' "$2" "$1"
}

# Runs the command word $1 with the words after it in the person's shell, so that their aliases and PATH work, in the
# same process group, so that Stop ends it.
in_shell() {
  line=$1
  shift
  "$(person_shell)" -ic "set +m; $line \"\$@\"" "$line" "$@"
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
  step=$(get "$build" step)
  openspot toast --id "build-$build" "$work ${step:-}" > /dev/null 2>&1 || true
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
  made=$(get "$1" spot)
  is_draft "$made" || return 0
  sed -i '' -E "/^state *= *[\"']draft[\"']/d" "$folder/$made.spot/spot.toml"
  openspot grid top "$made" > /dev/null 2>&1 || true
}

# Runs the agent $3 with no window for the build $1, with the prompt $4 on its stdin. The run prints its title, the step
# that the agent last reported and its progress, which the card of New spot shows. An agent that reports no step shows
# for how long it has worked.
run() {
  build=$1
  kind=$(way_of "$3" '' kind)
  line=$(way_of "$3" '' word) || { echo "Openspot cannot find $3." >&2; exit 1; }
  words=$4
  mkdir -p "$folder" "${builds:?}/$1"
  log="$builds/$1/log"
  name=$(get "$1" spot)
  if is_draft "$name"; then work='Building a spot…'; else work="Changing $name…"; fi
  put "$1" pid "$$"
  put "$1" state running
  agent_pid=
  trap '[ -z "$agent_pid" ] || { pkill -TERM -P "$agent_pid"; kill -TERM "$agent_pid"; } 2>/dev/null; openspot toast --remove "build-$build" > /dev/null 2>&1; put "$build" state stopped; moved "$build"; exit 0' TERM INT
  start='Starting the agent…'
  put "$1" step "$start"
  put "$1" said ''
  progress 0.03
  moved "$1"
  session=$(get "$1" session)
  openspot_path=$(command -v openspot)
  cd "$folder" || exit 1
  case $kind in
    claude)
      if [ -n "$session" ]; then
        set -- --resume "$session"
      else
        session=$(uuidgen | tr 'A-Z' 'a-z')
        put "$build" session "$session"
        set -- --session-id "$session"
      fi
      set -- -p "$@" --permission-mode acceptEdits --add-dir "$folder" \
        --allowedTools Read Write Edit Glob Grep "Bash($openspot_path:*)" "Bash(\"$openspot_path\":*)" "Bash(openspot:*)" \
        "Bash(chmod:*)" "Bash(mkdir:*)" "Bash(ls:*)" "Bash(cat:*)" "Bash(swift:*)" "Bash(swiftc:*)"
      ;;
    codex) set -- exec --skip-git-repo-check -s workspace-write -c sandbox_workspace_write.network_access=true -C "$folder" - ;;
    *) echo "Openspot cannot run $3 with no window." >&2; exit 1 ;;
  esac
  printf '%s' "$words" | in_shell "$line" "$@" > "$log" 2>&1 &
  agent_pid=$!
  began=$(date +%s)
  shown=$start
  fill=3
  while kill -0 "$agent_pid" 2>/dev/null; do
    sleep 1
    now=$(get "$build" step)
    if [ "$now" = "$start" ] || [ "${now#Working for }" != "$now" ]; then
      minutes=$((($(date +%s) - began) / 60))
      [ "$minutes" -lt 1 ] || { now="Working for $minutes min"; put "$build" step "$now"; }
    fi
    [ "$now" != "$shown" ] || continue
    shown=$now
    [ "$fill" -ge 90 ] || fill=$((fill + 4))
    progress "0.$(printf '%02d' "$fill")"
    moved "$build"
  done
  wait "$agent_pid"
  code=$?
  agent_pid=
  if [ "$code" -ne 0 ] || ! has_script "$name"; then
    if [ "$code" -ne 0 ]; then
      said=$(awk 'NF { last = $0 } END { print last }' "$log" | cut -c 1-160)
    else
      said='The agent is done, but made no spot.'
    fi
    openspot toast --remove "build-$build" > /dev/null 2>&1 || true
    put "$build" state failed
    put "$build" said "${said:-The agent stopped and gave no answer.}"
    moved "$build"
    [ -z "${OPENSPOT_EDIT-}" ] || { sheet ''; printf -- '---\n'; }
    echo "The agent stopped: ${said:-it gave no answer}." >&2
    exit 1
  fi
  # The build is done before its spot shows, so that the spot never comes while New spot still shows it as build.
  put "$build" state ready
  moved "$build"
  publish "$build"
  shown "$build" "$name"
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

# Opens a new tab of the terminal $2 that runs the agent $1 in the person's shell in the spots folder, with the prompt
# as its first message.
terminal() {
  line=$(way_of "$1" '' word) || { echo "Openspot cannot find $1." >&2; exit 1; }
  mkdir -p "$folder" "$OPENSPOT_DATA/terminal"
  stamp=$(date +%s)
  printf '%s' "$3" > "$OPENSPOT_DATA/terminal/$stamp.prompt"
  case $(way_of "$1" '' kind) in
    claude) [ -z "$build" ] || { session=$(get "$build" session) && [ -n "$session" ] && line="$line --resume $session"; } ;;
    codex) line="$line -c sandbox_workspace_write.network_access=true" ;;
  esac
  {
    printf '#!/bin/sh\ncd %s || exit 1\n' "$(quote "$folder")"
    printf 'exec %s -ic %s %s\n' "$(person_shell)" "$(quote "$line \"\$(cat \"\$0\")\"")" "$(quote "$OPENSPOT_DATA/terminal/$stamp.prompt")"
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
