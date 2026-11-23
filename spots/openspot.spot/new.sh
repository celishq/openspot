#!/bin/sh
# title=New spot
# icon=plus
# detail=Make your own
# on=sheet.open
# on=build.step
# emits=build.step
# uses=clipboard
# edits=spots
# offers=card
# pages=build:*
# pages=history
#
# field=agent
# title=Agent
. "$OPENSPOT_SH"
folder="${OPENSPOT_SPOTS:-$OPENSPOT_CONFIG/spots}"
builds="$OPENSPOT_DATA/builds"
nl='
'

# Each build is a folder in `builds`, with the words last sent, the spot it made, its state (running, ready, failed or
# done), the step it is on, the agent's last words and its session. Builds run side by side, each in its own call, and
# each shows on its own page, build:<id>. The first sheet starts a new one. The Edit sheet of a spot shows its last build.
job=
case ${OPENSPOT_PAGE-} in build:*) job=${OPENSPOT_PAGE#build:} ;; esac

# Prints the file $2 of the build $1, or nothing.
get() {
  cat "${builds:?}/$1/$2" 2>/dev/null
}

# Keeps $3 as the file $2 of the build $1.
put() {
  mkdir -p "${builds:?}/$1" && printf '%s' "$3" > "$builds/$1/$2.$$" && mv "$builds/$1/$2.$$" "$builds/$1/$2"
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

agent_bin() {
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

# Prints the app of the way $1: the terminal or the app it opens.
target() {
  printf '%s\n' "$all_ways" | awk -F '\t' -v id="$1" '$1 == id { print $4 }'
}

# Prints the id of the chosen way: the setting when this Mac still has it, or else the first way it has.
chosen() {
  list=$all_ways
  want=${1:-${OPENSPOT_SETTING_AGENT-}}
  printf '%s\n' "$list" | awk -F '\t' -v want="$want" '$1 == want { print $1; found = 1; exit } NR == 1 { first = $1 } END { if (!found && first != "") print first }'
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

# Prints the grid lines of the form.
form_grid() {
  key=$(next_key)
  printf 'grid=describe describe describe describe\ngrid=describe describe describe describe\ngrid=describe describe describe describe\n'
  if [ -n "$(go_title "$(chosen)")" ]; then
    printf 'grid=agent agent agent agent\ngrid=copy copy %s %s\n' "$key" "$key"
  else
    printf 'grid=copy copy copy copy\n'
  fi
}

# Prints the field, the agent and the two buttons, under the grid lines of form_grid.
form() {
  way=$(chosen)
  go=$(go_title "$way")
  printf 'field=describe\ntype=multiline\nplaceholder=%s\n' "$placeholder"
  openspot_kv value "$1"
  if [ -n "$go" ]; then
    printf '\nbutton=copy\ntitle=%s\nshortcut=cmd+shift+return\n\n' "${2:-Copy prompt}"
    printf 'button=%s\ntitle=%s\nlook=strong\nshortcut=cmd+return\n\n' "$(next_key)" "$go"
    printf 'choice=agent\ntitle=Agent\nvalue=%s\n\n' "$way"
    printf '%s\n' "$all_ways" | while IFS='	' read -r id title place target; do printf 'option=%s\ntitle=%s\n\n' "$id" "$title"; done
  else
    printf '\nbutton=copy\ntitle=%s\nlook=strong\nshortcut=cmd+return\n\n' "${2:-Copy prompt}"
  fi
  printf 'button=clear\ntitle=Clear\nscope=spot\n\n'
  printf 'button=guide\ntitle=Read the guide\nscope=spot\nclose=true\n\n'
}

# Marks a running build whose call is gone, such as one that Stop or a quit ended, as stopped.
settle() {
  [ "$(get "$1" state)" = running ] || return 0
  pid=$(get "$1" pid)
  [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null && return 0
  put "$1" state failed
  put "$1" said 'Stopped before it was done.'
}

# Prints the builds that are not done, the newest first.
active() {
  for dir in $(ls -1t "${builds:?}" 2>/dev/null); do
    settle "$dir"
    case $(get "$dir" state) in running | ready | failed) printf '%s\n' "$dir" ;; esac
  done
}

# Prints the first sheet: a line for each build that is not done, with Show, which opens its page, then the form of a new
# one. The lines are words, not rows, so that the field keeps the only focus.
first_sheet() {
  printf '%s' "$2"
  list=$(active | head -n 3)
  [ -z "$list" ] || printf '%s\n' "$list" | while IFS= read -r dir; do printf 'grid=b-%s b-%s b-%s show-%s\n' "$dir" "$dir" "$dir" "$dir"; done
  form_grid
  printf '\n'
  form "$1" "$3"
  [ ! -s "$OPENSPOT_DATA/history" ] || printf 'button=history\ntitle=History\nscope=spot\nshortcut=cmd+y\n\n'
  printf 'button=folder\ntitle=Open spots folder\nscope=spot\nclose=true\n\n'
  [ -z "$list" ] || printf '%s\n' "$list" | while IFS= read -r dir; do
    name=$(get "$dir" spot)
    printf 'text=b-%s\n' "$dir"
    openspot_kv title "${name:-$(get "$dir" asked | cut -c 1-48)}"
    case $(get "$dir" state) in
      running) printf 'icon=sparkles\n'; openspot_kv detail "$(get "$dir" step)" ;;
      ready) printf 'icon=checkmark.circle.fill\ndetail=Ready\ntone=good\n' ;;
      failed) printf 'icon=exclamationmark.triangle.fill\ndetail=Stopped\ntone=bad\n' ;;
    esac
    printf '\nbutton=show-%s\ntitle=Show\nlook=chip\n\n' "$dir"
  done
}

# Prints the page of the build $job: its steps while it runs, then the spot it made and the form of the next change.
build_sheet() {
  printf '%s' "$2"
  settle "$job"
  state=$(get "$job" state)
  if [ "$state" = running ]; then
    key=$(get "$job" key)
    printf 'grid=asked asked asked asked\ngrid=step step step step\ngrid=step step step step\ngrid=%s %s %s %s\n\n' "$key" "$key" "$key" "$key"
    printf 'text=asked\nlook=tile\n'
    openspot_kv title "$(get "$job" asked)"
    printf '\ntext=step\nicon=sparkles\n'
    openspot_kv title "$(get "$job" step)"
    said=$(get "$job" said)
    [ -z "$said" ] || openspot_kv detail "$said"
    printf '\nbutton=%s\ntitle=Stop\nlook=strong\nshortcut=cmd+return\n' "$key"
    return
  fi
  if [ "$state" = failed ]; then
    printf 'grid=made made made done\n'
  elif [ -n "$spot" ] && [ -z "${OPENSPOT_EDIT-}" ]; then
    printf 'grid=made made open done\n'
  fi
  form_grid
  printf '\n'
  if [ "$state" = failed ]; then
    printf 'text=made\nicon=exclamationmark.triangle.fill\ntone=bad\n'
    openspot_kv title "$(get "$job" said)"
    printf '\nbutton=done\ntitle=Done\nlook=chip\nshortcut=cmd+d\n\n'
  elif [ -n "$spot" ] && [ -z "${OPENSPOT_EDIT-}" ]; then
    printf 'text=made\nicon=checkmark.circle.fill\n'
    openspot_kv title "$spot"
    printf '\nbutton=open\ntitle=Open\nlook=chip\nshortcut=cmd+o\n\n'
    printf 'button=done\ntitle=Done\nlook=chip\nshortcut=cmd+d\n\n'
  fi
  form "$1" "$3"
  [ -n "${OPENSPOT_EDIT-}" ] || printf 'button=remove\ntitle=Remove from the list\nscope=spot\nshortcut=cmd+backspace\n\n'
  [ -z "${OPENSPOT_EDIT_FILE-}" ] || printf 'button=editor\ntitle=Open in editor\nscope=spot\nclose=true\n\n'
}

sheet() {
  if [ -n "$job" ]; then build_sheet "$@"; else first_sheet "$@"; fi
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

# The words of the field: the ones on stdin when the sheet sends them, or else the draft.
case "$nl$(openspot_input)" in
  *"${nl}describe="*)
    typed=$(value describe; printf x)
    typed=${typed%x}
    mkdir -p "${draft%/*}" && printf '%s' "$typed" > "$draft.$$" && mv "$draft.$$" "$draft"
    ;;
  *)
    typed=$(cat "$draft" 2>/dev/null; printf x)
    typed=${typed%x}
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
  openspot event emit build.step "$1" > /dev/null 2>&1 || true
}

# Runs the agent $3 with no window for the build $1, started by the button $2, with the prompt $4. Each step goes to the
# build's files and tells the sheet. The call itself prints only its title and progress, which the search row shows.
run() {
  bin=$(agent_bin "$3") || { echo "Openspot cannot find $3." >&2; exit 1; }
  mkdir -p "$folder" "${builds:?}/$1"
  log="$builds/$1/log"
  ending="$builds/$1/end"
  name=$(get "$1" spot)
  if [ -n "$name" ]; then work="Changing $name…"; else work='Building a spot…'; fi
  put "$1" key "$2"
  put "$1" pid "$$"
  put "$1" state running
  trap 'put "$1" state failed; put "$1" said "Stopped before it was done."; moved "$1"; exit 1' TERM INT
  put "$1" step 'Starting the agent…'
  put "$1" said ''
  put "$1" end ''
  head=$(printf 'background=true\ntitle=%s\nprogress=0.03\n' "$work")
  if [ -z "$was" ]; then
    printf '%s\npush=build:%s\n' "$head" "$1"
    openspot_kv push.title "$(name_of "$1")"
  else
    build_sheet "" "$head$nl"
  fi
  printf -- '---\n'
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
            printf 'background=true\ntitle=%s\nprogress=0.%02d\n---\n' "$work" "$fill"
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
  if [ -n "$was" ]; then printf 'toast=Changed %s.\n' "$name"; else printf 'toast=Made %s.\n' "$name"; fi
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

# Hands the words off the chosen way, from the button $1. Here starts a build: a new one from the first sheet, or the
# next change of the build whose page shows.
go() {
  text=$(trimmed)
  [ -n "$text" ] || { sheet "$typed" "toast=Describe it first.$nl"; return; }
  words=$(prompt "$text") || exit 1
  way=$(chosen)
  count=$(cat "$OPENSPOT_DATA/runs.count" 2>/dev/null || echo 0)
  printf '%s' "$((count + 1))" > "$OPENSPOT_DATA/runs.count"
  printf '' > "$draft"
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
      sheet "" "toast=Opened $(target "$way").$nl"
      ;;
    app-*)
      in_app "$(target "$way")" "$words"
      sheet "" "toast=Prompt copied. Paste it with ⌘V.$nl"
      ;;
    *)
      echo 'This Mac has no agent that New spot knows.' >&2
      exit 1
      ;;
  esac
}

# Prints the History page: each spot made here, the newest first, with the last words sent for it.
history_page() {
  printf 'recents=false\n\n'
  [ -s "$OPENSPOT_DATA/history" ] || { printf 'text=empty\ntitle=No spots made here yet\n'; return; }
  printf 'button=open\ntitle=Go on with it\n\n'
  seen=
  tail -r "$OPENSPOT_DATA/history" | while IFS='	' read -r when dir words; do
    name=$(get "$dir" spot)
    [ -n "$name" ] && [ -d "$folder/$name.spot" ] || continue
    case " $seen " in *" $name "*) continue ;; esac
    seen="$seen $name"
    printf 'row=build:%s\nicon=sparkles\n' "$dir"
    openspot_kv title "$name"
    openspot_kv detail "$(date -r "$when" '+%-d %b, %H:%M') · $words"
    printf '\n'
  done
}

if [ "${OPENSPOT_PAGE-}" = history ]; then
  case "$1" in
    read) history_page ;;
    open)
      dir=${2#build:}
      [ "$(get "$dir" state)" != done ] || put "$dir" state ready
      printf 'push=%s\npush.replace=true\n' "$2"
      openspot_kv push.title "$(get "$dir" spot)"
      ;;
  esac
  exit 0
fi

case "$1" in
  read | describe) sheet "$typed" ;;
  agent)
    way=${2:-$(value agent)}
    if [ -z "$way" ]; then
      printf 'title=Agent\n\nchoice=agent\nvalue=%s\n\n' "$(chosen)"
      printf '%s\n' "$all_ways" | while IFS='	' read -r id title place target; do printf 'option=%s\ntitle=%s\n\n' "$id" "$title"; done
      exit 0
    fi
    openspot setting set agent "$way" > /dev/null || exit 1
    OPENSPOT_SETTING_AGENT=$way
    sheet "$typed"
    ;;
  copy)
    words=$(prompt "$(trimmed)") || exit 1
    printf '%s' "$words" | openspot clipboard copy || exit 1
    printf '' > "$draft"
    sheet "$typed" "toast=Prompt copied. Paste it into your agent.$nl" "✓ Copied"
    printf -- '---\n'
    sleep 1.5
    sheet ""
    ;;
  make-* | change-*) go "$1" ;;
  open) [ -z "$spot" ] || printf 'push.spot=%s\n' "$spot" ;;
  'done')
    [ -z "$job" ] || put "$job" state done
    printf 'pop=true\ntoast=Done. History (⌘Y) takes you back to it.\n'
    ;;
  history) printf 'push=history\npush.title=History\n' ;;
  show-*)
    dir=${1#show-}
    printf 'push=build:%s\n' "$dir"
    openspot_kv push.title "$(name_of "$dir")"
    ;;
  remove)
    dir=$job
    case $dir in '' | */* | .*) exit 1 ;; esac
    settle "$dir"
    [ "$(get "$dir" state)" != running ] || { echo 'Stop this build first.' >&2; exit 1; }
    rm -rf "${builds:?}/$dir"
    printf 'pop=true\n'
    ;;
  clear)
    printf '' > "$draft"
    sheet ""
    ;;
  editor)
    open -t "$OPENSPOT_EDIT_FILE"
    ;;
  guide)
    openspot guide > "$OPENSPOT_DATA/GUIDE.md" && open "$OPENSPOT_DATA/GUIDE.md"
    ;;
  folder)
    mkdir -p "$folder" && open "$folder"
    ;;
  *)
    echo 'New spot cannot do that.' >&2
    exit 1
    ;;
esac
