#!/bin/sh
. "$OPENSPOT_SH"
folder="${OPENSPOT_SPOTS:-$OPENSPOT_CONFIG/spots}"
builds="$OPENSPOT_DATA/builds"
nl='
'

# A search ends with a row that makes a spot of the typed words, and a pick of it copies their prompt.
if [ "$1" = search ]; then
  text=$(value text | awk '{ sub(/^[ \t]+/, ""); sub(/[ \t]+$/, ""); print }')
  [ -z "$text" ] || openspot_item "$text" 'Make a spot' "$text" plus
  exit 0
fi
if [ "$1" = press ]; then
  words=$(openspot prompt new "$(value item)") || exit 1
  printf '%s' "$words" | openspot clipboard copy || exit 1
  openspot toast 'Prompt copied. Paste it into your agent.'
  exit 0
fi

# Each build is a folder in `builds`, with the words last sent, the spot it made, its state (running, ready, failed or
# done), the step it is on, the agent's last words and its session. Builds run side by side, each in its own call, and
# each shows on its own page, build/<id>. The first sheet starts a new one. The Edit sheet of a spot shows its last build.
route=$(value route)
job=
case $route in build/*) job=${route#build/} ;; esac
case $job in */* | .*) job= ;; esac

# Prints the file $2 of the build $1, or nothing.
get() {
  cat "${builds:?}/$1/$2" 2>/dev/null
}

# Keeps $3 as the file $2 of the build $1.
put() {
  openspot_keep "${builds:?}/$1/$2" "$3"
}

# Prints the name of the build $1: its spot, or the first words sent.
name_of() {
  name=$(get "$1" spot)
  [ -n "$name" ] || name=$(get "$1" asked | cut -c 1-40)
  printf '%s' "${name:-New spot}"
}

# Prints the last build of the spot $1.
build_of() {
  for dir in $(ls -1t "${builds:?}" 2>/dev/null); do
    [ "$(get "$dir" spot)" = "$1" ] && { printf '%s' "$dir"; return; }
  done
}

if [ -n "${OPENSPOT_EDIT-}" ]; then
  job=$(build_of "$OPENSPOT_EDIT")
  if [ -z "$job" ]; then
    job="e$(date +%s)$$"
    put "$job" spot "$OPENSPOT_EDIT"
    put "$job" state ready
  fi
fi
spot=
[ -z "$job" ] || spot=$(get "$job" spot)

if [ -n "$job" ]; then
  draft="$builds/$job/draft"
  placeholder="Describe a change to ${spot:-this spot}"
else
  draft="$OPENSPOT_DATA/draft"
  placeholder='Describe what you want to build'
fi
copied="$draft.copied"

agent_bin() {
  command -v "$1" 2>/dev/null && return
  for path in "$HOME/.local/bin/$1" "$HOME/.claude/local/$1" "/opt/homebrew/bin/$1" "/usr/local/bin/$1" "$HOME/.npm-global/bin/$1" "$HOME/.bun/bin/$1"; do
    [ -x "$path" ] && { printf '%s' "$path"; return; }
  done
  return 1
}

app_path() {
  for path in "/Applications/$1.app" "$HOME/Applications/$1.app" "/System/Applications/Utilities/$1.app"; do
    [ -d "$path" ] && { printf '%s' "$path"; return; }
  done
  return 1
}

slug() {
  printf '%s' "$1" | tr 'A-Z' 'a-z' | tr -cd 'a-z0-9'
}

ways() {
  for cli in claude:'Claude Code' codex:Codex gemini:'Gemini CLI' opencode:opencode; do
    agent_bin "${cli%%:*}" > /dev/null || continue
    case ${cli%%:*} in claude | codex) printf 'here-%s\t%s here\there\n' "${cli%%:*}" "${cli#*:}" ;; esac
    for term in Ghostty iTerm Warp Terminal; do
      app_path "$term" > /dev/null && printf 'term-%s-%s\t%s in %s\t%s\t%s\n' "${cli%%:*}" "$(slug "$term")" "${cli#*:}" "$term" "$term" "$term"
    done
  done
  for app in 'Claude' 'Codex' 'Cursor' 'T3 Code (Beta)' 'T3 Code'; do
    app_path "$app" > /dev/null && printf 'app-%s\t%s app\t%s\t%s\n' "$(slug "${app% (Beta)}")" "${app% (Beta)}" "${app% (Beta)}" "$app"
  done
}

all_ways=$(ways)
agent=$(value setting.agent)

# Prints the app of the way $1: the terminal or the app it opens.
target() {
  printf '%s\n' "$all_ways" | awk -F '\t' -v id="$1" '$1 == id { print $4 }'
}

# Prints the id of the chosen way: the setting when this Mac still has it, or else the first way it has.
chosen() {
  printf '%s\n' "$all_ways" | awk -F '\t' -v want="$agent" '$1 == want { print $1; found = 1; exit } NR == 1 { first = $1 } END { if (!found && first != "") print first }'
}

# Prints the words of the button of a way: Make here, Make in Ghostty, or Change here on a build.
go_title() {
  verb=Make
  [ -z "$job" ] || verb=Change
  place=$(printf '%s\n' "$all_ways" | awk -F '\t' -v id="$1" '$1 == id { print $3 }')
  case $place in
    '') printf '' ;;
    here) printf '%s here' "$verb" ;;
    *) printf '%s in %s' "$verb" "$place" ;;
  esac
}

# Prints the id of the button that starts the next run: a new one for each run, so that runs go on side by side.
next_key() {
  count=$(cat "$OPENSPOT_DATA/runs.count" 2>/dev/null || echo 0)
  if [ -n "$job" ]; then printf 'change-%s-%s' "$job" "$count"; else printf 'make-%s' "$count"; fi
}

# Prints the options of the agent choice.
options() {
  printf '%s\n' "$all_ways" | while IFS='	' read -r id title place target; do
    printf '\noption=%s\n' "$id"
    openspot_kv title "$title"
  done
}

# Prints the field with the words $1, then a row of the agent and the two buttons, Copy prompt with the words $2.
form() {
  way=$(chosen)
  go=$(go_title "$way")
  printf '\nfield=describe\ntype=multiline\nclass=grow\n'
  openspot_kv placeholder "$placeholder"
  openspot_kv value "$1"
  if [ -n "$go" ]; then
    printf '\nchoice=agent\ntitle=Agent\nvalue=%s\n' "$way"
    options
    printf '\nbox=go\nclass=grid grid-cols-2 gap-2\n'
    printf '\nbutton=copy\nparent=go\ntitle=%s\nshortcut=cmd+shift+return\nclose=false\n' "${2:-Copy prompt}"
    printf '\nbutton=%s\nparent=go\ntitle=%s\nclass=bg-accent\nshortcut=cmd+return\nclose=false\n' "$(next_key)" "$go"
  else
    printf '\nbox=go\nclass=flex-row gap-2\n'
    printf '\nbutton=copy\nparent=go\ntitle=%s\nclass=grow bg-accent\nshortcut=cmd+return\nclose=false\n' "${2:-Copy prompt}"
  fi
  printf '\nbutton=clear\ntitle=Clear\nscope=spot\nclose=false\n'
  [ -z "${OPENSPOT_EDIT_FILE-}" ] || printf '\nbutton=editor\ntitle=Open in editor\nscope=spot\n'
  printf '\nbutton=guide\ntitle=Read the guide\nscope=spot\n'
}

# Marks a running build whose call is gone, such as one that Stop or a quit ended, as stopped.
settle() {
  [ "$(get "$1" state)" = running ] || return 0
  pid=$(get "$1" pid)
  [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null && return 0
  put "$1" state failed
  put "$1" said 'Stopped before it was done.'
}

# How long Undo stays after Done, in seconds.
undo_time=6

# Prints the builds that show on the first sheet, the newest first: each that is not done, and each done in the last
# seconds of undo_time, which offers Undo.
active() {
  now=$(date +%s)
  for dir in $(ls -1t "${builds:?}" 2>/dev/null); do
    settle "$dir"
    case $(get "$dir" state) in
      running | ready | failed) printf '%s\n' "$dir" ;;
      done)
        at=$(get "$dir" done.at)
        [ -n "$at" ] && [ $((now - at)) -lt "$undo_time" ] && printf '%s\n' "$dir"
        ;;
    esac
  done
}

# Prints the first sheet: a line for each build that shows, with Show, which opens its page, then the form of a new
# one. The lines are words, not items, so that the field keeps the only focus.
first_sheet() {
  printf 'frame=\nclass=gap-group\n'
  list=$(active | head -n 3)
  if [ -n "$list" ]; then
    printf '\nbox=builds\nclass=flex-col gap-1\n'
    printf '%s\n' "$list" | while IFS= read -r dir; do
      state=$(get "$dir" state)
      printf '\nbox=b-%s\nparent=builds\nclass=flex-row items-center gap-2\n' "$dir"
      case $state in
        running) icon=sparkles look=text-accent words=$(get "$dir" step) ;;
        ready) icon=checkmark.circle.fill look=text-good words=Ready ;;
        failed) icon=exclamationmark.triangle.fill look=text-bad words=Stopped ;;
        *) icon=checkmark.circle look=text-secondary words=Done ;;
      esac
      printf '\nicon=i-%s\nparent=b-%s\nvalue=%s\nclass=%s\n' "$dir" "$dir" "$icon" "$look"
      printf '\ntext=t-%s\nparent=b-%s\nclass=grow truncate\n' "$dir" "$dir"
      openspot_kv title "$(name_of "$dir") · $words"
      if [ "$state" = done ]; then
        printf '\nbutton=undo-%s\nparent=b-%s\ntitle=Undo\nclass=rounded-full\nclose=false\n' "$dir" "$dir"
      else
        printf '\nbutton=show-%s\nparent=b-%s\ntitle=Show\nclass=rounded-full\nclose=false\n' "$dir" "$dir"
      fi
    done
  fi
  form "$1" "$2"
  [ ! -s "$OPENSPOT_DATA/history" ] || printf '\nbutton=history\ntitle=History\nscope=spot\nshortcut=cmd+y\nclose=false\n'
  printf '\nbutton=folder\ntitle=Open spots folder\nscope=spot\n'
}

# Prints the page of the build $job: its step while it runs, then the spot it made and the form of the next change.
build_sheet() {
  settle "$job"
  state=$(get "$job" state)
  printf 'frame=%s\nclass=gap-group\n' "$route"
  if [ "$state" = running ]; then
    printf '\ntext=asked\nclass=bg-tile rounded-inner p-part line-clamp-3\n'
    openspot_kv title "$(get "$job" asked)"
    printf '\nbox=now\nclass=flex-row items-start gap-2 grow\n'
    printf '\nicon=now-icon\nparent=now\nvalue=sparkles\nclass=text-accent\n'
    printf '\ntext=step\nparent=now\nclass=grow\n'
    openspot_kv title "$(get "$job" step)"
    said=$(get "$job" said)
    [ -z "$said" ] || openspot_kv detail "$said"
    printf '\nbutton=stop-%s\ntitle=Stop\nclass=self-end\nshortcut=cmd+return\nclose=false\n' "$job"
    return
  fi
  edit=${OPENSPOT_EDIT-}
  if [ "$state" = failed ]; then
    printf '\nbox=made\nclass=flex-row items-center gap-2\n'
    printf '\nicon=made-icon\nparent=made\nvalue=exclamationmark.triangle.fill\nclass=text-bad\n'
    printf '\ntext=made-name\nparent=made\nclass=grow line-clamp-2\n'
    openspot_kv title "$(get "$job" said)"
    [ -n "$edit" ] || printf '\nbutton=done-%s\nparent=made\ntitle=Done\nclass=rounded-full\nshortcut=cmd+d\nclose=false\n' "$job"
  elif [ -n "$spot" ] && [ -z "$edit" ]; then
    printf '\nbox=made\nclass=flex-row items-center gap-2\n'
    printf '\nicon=made-icon\nparent=made\nvalue=checkmark.circle.fill\nclass=text-good\n'
    printf '\ntext=made-name\nparent=made\nclass=grow truncate\n'
    openspot_kv title "$spot"
    [ "$state" = done ] || printf '\nbutton=done-%s\nparent=made\ntitle=Done\nclass=rounded-full\nshortcut=cmd+d\nclose=false\n' "$job"
    printf '\nbutton=open\nparent=made\ntitle=Open\nclass=rounded-full\nshortcut=cmd+o\nclose=false\n'
  fi
  form "$1" "$2"
  [ -n "$edit" ] || printf '\nbutton=remove\ntitle=Remove from the list\nscope=spot\nshortcut=cmd+backspace\nclose=false\n'
}

# Prints the History page: each spot made here, the newest first, with the last words sent for it.
history_page() {
  printf 'frame=history\nrecents=false\n'
  [ -s "$OPENSPOT_DATA/history" ] || { printf '\ntext=empty\ntitle=No spots made here yet\n'; return; }
  seen=
  tail -r "$OPENSPOT_DATA/history" | while IFS='	' read -r when dir words; do
    name=$(get "$dir" spot)
    [ -n "$name" ] && [ -d "$folder/$name.spot" ] || continue
    case " $seen " in *" $name "*) continue ;; esac
    seen="$seen $name"
    printf '\nitem=%s\nicon=sparkles\nroute=build/%s\n' "$dir" "$dir"
    openspot_kv title "$name"
    openspot_kv detail "$(date -r "$when" '+%-d %b, %H:%M') · $words"
  done
}

sheet() {
  if [ "$route" = history ]; then
    history_page
  elif [ -n "$job" ]; then
    build_sheet "$@"
  else
    first_sheet "$@"
  fi
}

# Prints the prompt for the agent: to change the spot of this build, or to build a new one, as the words say.
prompt() {
  if [ -n "$spot" ]; then
    set -- "$spot" ${OPENSPOT_EDIT_FAILURE:+--failure "$OPENSPOT_EDIT_FAILURE"} ${1:+"$1"}
    openspot prompt change "$@"
  elif [ -n "$1" ]; then
    openspot prompt new "$1"
  else
    openspot prompt new
  fi
}

# The words of the field: the ones on stdin when the sheet sends them, or else the draft that a last call kept. A draft
# that was copied or handed off is done, so the sheet opens empty.
case "$nl$(openspot_input)" in
  *"${nl}input.describe="*)
    typed=$(value input.describe; printf x)
    typed=${typed%x}
    openspot_keep "$draft" "$typed"
    ;;
  *)
    typed=$(cat "$draft" 2>/dev/null; printf x)
    typed=${typed%x}
    if [ -f "$copied" ] && [ "$typed" = "$(cat "$copied")" ]; then
      rm -f "$draft" "$copied"
      typed=
    fi
    ;;
esac

# Prints the words of the field with no blank lines around them.
trimmed() {
  printf '%s' "$typed" | awk '{ lines[NR] = $0 } END { s = ""; for (i = 1; i <= NR; i++) s = s (i > 1 ? "\n" : "") lines[i]; sub(/^[ \t\n]+/, "", s); sub(/[ \t\n]+$/, "", s); printf "%s", s }'
}

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

# Prints a frame that only says how far the background run is, which the search row shows.
progress() {
  printf 'frame=\nbackground=true\n'
  openspot_kv title "$work"
  printf 'progress=%s\n\n---\n' "$1"
}

# Runs the agent $3 with no window for the build $1, with the prompt $4. Each step goes to the build's files and tells
# the sheet. The run itself prints only its title and progress, so Openspot shows no working card for it.
run() {
  building=$1
  bin=$(agent_bin "$3") || { echo "Openspot cannot find $3." >&2; exit 1; }
  mkdir -p "$folder" "${builds:?}/$1"
  log="$builds/$1/log"
  name=$(get "$1" spot)
  if [ -n "$name" ]; then work="Changing $name…"; else work='Building a spot…'; fi
  put "$1" pid "$$"
  put "$1" state running
  trap 'put "$building" state failed; put "$building" said "Stopped before it was done."; moved "$building"; exit 0' TERM INT
  put "$1" step 'Starting the agent…'
  put "$1" said ''
  put "$1" end ''
  progress 0.03
  if [ -z "$was" ]; then openspot route push "build/$1" --title "$(name_of "$1")" > /dev/null 2>&1 || true; fi
  moved "$1"
  session=$(get "$1" session)
  before=$(ls -1 "$folder")
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
                case $one:$two in
                  Write:"$folder"/*.spot/*)
                    made=${two#"$folder"/}
                    made=${made%%.spot/*}
                    if [ -z "$(get "$1" spot)" ] && ! printf '%s\n' "$before" | grep -qxF "$made.spot"; then
                      put "$1" spot "$made"
                    fi
                    ;;
                esac
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
  if [ -z "$failed" ] || [ "$failed" = true ] || [ -z "$name" ]; then
    [ -n "$said" ] || said=$(tail -n 1 "$log")
    [ -n "$name" ] || [ "$failed" = true ] || said='The agent is done, but made no spot.'
    put "$1" state failed
    put "$1" said "${said:-The agent gave no answer.}"
    moved "$1"
    echo "The agent stopped: ${said:-it gave no answer}." >&2
    exit 1
  fi
  [ -z "$session" ] || put "$1" session "$session"
  put "$1" state ready
  printf '%s\t%s\t%s\n' "$(date +%s)" "$1" "$(get "$1" asked)" >> "$OPENSPOT_DATA/history"
  moved "$1"
  if [ -n "$was" ]; then openspot toast "Changed $name."; else openspot toast "Made $name."; fi
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

# Puts the prompt on the clipboard and opens the app $1, where a paste gives it to the agent.
in_app() {
  printf '%s' "$2" | openspot clipboard copy || exit 1
  open -a "$1" || { echo "Openspot cannot open $1." >&2; exit 1; }
}

# Prints a word between single quotes for a shell script.
quote() {
  printf "'%s'" "$(printf '%s' "$1" | sed "s/'/'\\\\''/g")"
}

# Hands the words off the chosen way. Here starts a build: a new one from the first sheet, or the next change of the
# build whose page shows.
go() {
  text=$(trimmed)
  if [ -z "$text" ]; then
    openspot toast 'Describe it first.'
    sheet "$typed"
    return
  fi
  words=$(prompt "$text") || exit 1
  way=$(chosen)
  count=$(cat "$OPENSPOT_DATA/runs.count" 2>/dev/null || echo 0)
  openspot_keep "$OPENSPOT_DATA/runs.count" "$((count + 1))"
  rm -f "$draft" "$copied"
  case $way in
    here-*)
      was=$job
      [ -n "$job" ] || job="b$(date +%s)$$"
      put "$job" asked "$(printf '%s' "$text" | tr '\n' ' ')"
      run "$job" "$1" "${way#here-}" "$words"
      ;;
    term-*)
      rest=${way#term-}
      terminal "${rest%%-*}" "$(target "$way")" "$words"
      openspot toast "Opened $(target "$way")."
      sheet ""
      ;;
    app-*)
      in_app "$(target "$way")" "$words"
      openspot toast 'Prompt copied. Paste it with ⌘V.'
      sheet ""
      ;;
    *)
      echo 'This Mac has no agent that New spot knows.' >&2
      exit 1
      ;;
  esac
}

case "$1" in
  show | describe | new.step) sheet "$typed" ;;
  agent)
    way=$(value input.value)
    if [ -z "$way" ] && [ -z "$(value input.agent)" ]; then
      printf 'frame=\ntype=form\ntitle=Agent\n\nchoice=agent\nvalue=%s\n' "$(chosen)"
      options
      exit 0
    fi
    [ -n "$way" ] || way=$(value input.agent)
    openspot setting set agent "$way" > /dev/null || exit 1
    agent=$way
    [ -z "$(value input.value)" ] || sheet "$typed"
    ;;
  copy)
    words=$(prompt "$(trimmed)") || exit 1
    printf '%s' "$words" | openspot clipboard copy || exit 1
    openspot_keep "$copied" "$typed"
    openspot toast 'Prompt copied. Paste it into your agent.'
    sheet "$typed" '✓ Copied'
    printf -- '---\n'
    sleep 1.5
    sheet "$typed"
    ;;
  make-* | change-*) go "$1" ;;
  stop-*)
    stop "${1#stop-}"
    sheet "$typed"
    ;;
  open) [ -z "$spot" ] || openspot spot push "$spot" > /dev/null ;;
  done-*)
    # Done takes the build off the first sheet, where it shows with Undo for undo_time seconds, then reads again.
    dir=${1#done-}
    case $dir in '' | */* | .*) exit 1 ;; esac
    put "$dir" state done
    put "$dir" done.at "$(date +%s)"
    openspot route back > /dev/null 2>&1 || true
    sleep "$undo_time"
    moved "$dir"
    ;;
  undo-*)
    dir=${1#undo-}
    case $dir in '' | */* | .*) exit 1 ;; esac
    [ "$(get "$dir" state)" != done ] || put "$dir" state ready
    rm -f "$builds/$dir/done.at"
    sheet "$typed"
    ;;
  history) openspot route push history --title History > /dev/null ;;
  show-*)
    dir=${1#show-}
    openspot route push "build/$dir" --title "$(name_of "$dir")" > /dev/null
    ;;
  remove)
    dir=$job
    case $dir in '' | */* | .*) exit 1 ;; esac
    settle "$dir"
    [ "$(get "$dir" state)" != running ] || { echo 'Stop this build first.' >&2; exit 1; }
    rm -rf "${builds:?}/$dir"
    openspot route back > /dev/null
    ;;
  clear)
    rm -f "$draft" "$copied"
    typed=
    sheet ""
    ;;
  editor)
    open -t "$OPENSPOT_EDIT_FILE"
    ;;
  guide)
    openspot guide > "$OPENSPOT_DATA/DOCS.md" && open "$OPENSPOT_DATA/DOCS.md"
    ;;
  folder)
    mkdir -p "$folder" && open "$folder"
    ;;
  *)
    echo 'New spot cannot do that.' >&2
    exit 1
    ;;
esac
