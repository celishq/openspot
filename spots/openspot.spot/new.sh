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

# Each build is a folder in `builds`, with the words last sent, the spot it made, its state (running, ready, failed, stopped, done or
# deleted), the step it is on, the agent's last words and its session. Builds run side by side, each in its own call, and
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
  name=$(title_of "$1" | cut -c 1-40)
  printf '%s' "${name:-New spot}"
}

# Prints the name a build goes by: the title of its spot once the agent has chosen it, so that people meet the spot by
# its name while it is built, or else its id, or else the words sent.
# A change of a spot that is already made goes by the words of the change, so that each change has its own name.
title_of() {
  made=$(get "$1" spot)
  words=$(short "$(get "$1" asked)")
  if [ -n "$(get "$1" change)" ] && [ -n "$words" ]; then
    printf '%s' "$words"
    return
  fi
  title=$(sed -n 's/^title *= *"\(.*\)" *$/\1/p' "$folder/$made.spot/spot.toml" 2>/dev/null | head -n 1)
  printf '%s' "${title:-${words:-$made}}"
}

# Prints a short name of the words $1: their first three words that say what, such as Log run distance for "spot to log
# run distance and show the week". Openspot shows it at once, and the agent is asked to give the spot that title.
short() {
  printf '%s\n' "$1" | /usr/bin/perl -CS -Mutf8 -ne '
    BEGIN { %stop = map { $_ => 1 } qw(a an the to that which who and or but for of with in on at by from my me i we you
      it its this these spot spots app widget please want would like make build create write new add show shows how much
      many is are be спот спота споти для на і й та що в у з із за до мені мене хочу треба зроби зробити створи створити
      додай як який яка яке скільки щоб) }
    for (split /[^\p{L}\p{N}\x27-]+/) { next if $_ eq ""; my $word = lc; push @words, $word unless $stop{$word}; last if @words == 3 }
    last if @words == 3;
    END { print ucfirst(join " ", @words) if @words }'
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

# The apps that New spot knows, each a bundle id and a name. Codex ships as ChatGPT.app, so New spot shows the name
# of the app on the Mac, the one people know.
known_apps='com.anthropic.claudefordesktop	Claude
com.openai.codex	Codex
com.todesktop.230313mzl4w4u92	Cursor
com.exafunction.windsurf	Windsurf
dev.zed.Zed	Zed
com.microsoft.VSCode	VS Code'

# The agents that New spot knows, each a key, the name people know it by, its command, the app it ships as, and yes
# when Openspot can run it with no window.
known_agents='claude|Claude Code|claude|Claude|yes
codex|Codex|codex|Codex|yes
gemini|Gemini CLI|gemini||
opencode|opencode|opencode||
amp|Amp|amp||
cursor|Cursor|cursor-agent||'

# The editors where Claude Code works through its extension, each the editor, its link scheme and its folder of
# extensions. A link opens a new Claude Code session there with the prompt.
editors='VS Code|vscode|.vscode
Cursor|cursor|.cursor
Windsurf|windsurf|.windsurf'

# Prints each known app on this Mac as its name and its path, found by its bundle id wherever it is, or else by its
# name in an Applications folder.
installed_apps() {
  query=$(printf '%s\n' "$known_apps" | awk -F '\t' '{ printf "%s kMDItemCFBundleIdentifier == \"%s\"", (NR > 1 ? " ||" : ""), $1 }')
  found=$(mdfind "$query" 2>/dev/null | grep '\.app$' | grep -v '/Library/')
  printf '%s\n' "$known_apps" | while IFS='	' read -r id name; do
    path=$(printf '%s\n' "$found" | while IFS= read -r app; do
      [ "$(plutil -extract CFBundleIdentifier raw "$app/Contents/Info.plist" 2>/dev/null)" = "$id" ] && { printf '%s' "$app"; break; }
    done)
    [ -n "$path" ] || path=$(app_path "$name") || path=$(app_path "$name (Beta)") || continue
    printf '%s\t%s\n' "$name" "$path"
  done
}

app_path() {
  for path in "/Applications/$1.app" "$HOME/Applications/$1.app" "/System/Applications/Utilities/$1.app"; do
    [ -d "$path" ] && { printf '%s' "$path"; return; }
  done
  return 1
}

apps=

# Prints the path of the known app $1, or fails.
app_of() {
  printf '%s\n' "${apps:-$(installed_apps)}" | awk -F '\t' -v name="$1" '$1 == name { print $2; found = 1; exit } END { exit !found }'
}

# Prints the path of the command $1 of an agent: on the PATH, which Openspot gives the folders where installers put it,
# or inside the app that ships it, as Codex does.
agent_bin() {
  command -v "$1" 2>/dev/null && return
  case $1 in
    codex)
      ships=$(app_of Codex) && [ -x "$ships/Contents/Resources/codex-cli/bin/codex" ] &&
        { printf '%s' "$ships/Contents/Resources/codex-cli/bin/codex"; return; }
      ;;
  esac
  return 1
}

# Prints a free id for a new spot from the words $1, such as log-run-distance, with a number after it when a spot or
# another build has it.
free_id() {
  base=$(printf '%s' "$1" | tr 'A-Z ' 'a-z-' | tr -cd 'a-z0-9-')
  [ -n "$base" ] || base=spot
  id=$base
  n=2
  while [ -e "$folder/$id.spot" ] || grep -qxF "$id" "${builds:?}"/*/spot 2>/dev/null; do
    id="$base-$n"
    n=$((n + 1))
  done
  printf '%s' "$id"
}

slug() {
  printf '%s' "$1" | tr 'A-Z' 'a-z' | tr -cd 'a-z0-9'
}

# Prints each way this Mac can run an agent, one line each: the agent, its name, the place, the place's name and what
# opens it. A place is Openspot, a terminal, or an app that takes the prompt in a link: the agent's own, or an editor
# with Claude Code. An app that takes no prompt adds nothing to Copy prompt, so New spot leaves it out.
ways() {
  apps=$(installed_apps)
  printf '%s\n' "$known_agents" | while IFS='|' read -r key name bin app here; do
    has_bin=
    [ -z "$bin" ] || ! agent_bin "$bin" > /dev/null || has_bin=1
    own=
    [ -z "$app" ] || own=$(app_of "$app") || own=
    [ -n "$has_bin" ] || [ -n "$own" ] || continue
    if [ -n "$has_bin" ]; then
      [ -z "$here" ] || printf '%s|%s|openspot|Openspot|\n' "$key" "$name"
    fi
    [ -z "$own" ] || printf '%s|%s|app-%s|%s|%s\n' "$key" "$name" "$(slug "$app")" "$(basename "$own" .app)" "$own"
    if [ -n "$has_bin" ]; then
      for term in Ghostty iTerm Warp Terminal; do
        app_path "$term" > /dev/null && printf '%s|%s|term-%s|%s|%s\n' "$key" "$name" "$(slug "$term")" "$term" "$term"
      done
    fi
    [ "$key" = claude ] || continue
    printf '%s\n' "$editors" | while IFS='|' read -r editor scheme extensions; do
      ls -d "$HOME/$extensions/extensions"/anthropic.claude-code-* > /dev/null 2>&1 && path=$(app_of "$editor") &&
        printf '%s|%s|app-%s|%s|%s\n' "$key" "$name" "$scheme" "$editor" "$path"
    done
  done
}

# The ways of this Mac, kept from the last look, since finding them takes a second. The first open looks at once, and
# each open after it looks again after the sheet shows.
kept_ways="$OPENSPOT_DATA/ways"
all_ways=$(cat "$kept_ways" 2>/dev/null)

# The chosen agent and place, from the settings. An agent of an older version names both, such as here-claude.
agent=$(value setting.agent)
place=$(value setting.place)
case $agent in
  here-*) place=${place:-openspot} agent=${agent#here-} ;;
  term-*) rest=${agent#term-} && agent=${rest%%-*} && place=${place:-term-${rest#*-}} ;;
  app-*) place=${place:-$agent} agent=${agent#app-} ;;
esac

# Prints the chosen agent: the setting when this Mac still has it, or else the first.
chosen_agent() {
  printf '%s\n' "$all_ways" | awk -F '|' -v want="$agent" 'NR == 1 { first = $1 } $1 == want { print $1; found = 1; exit } END { if (!found && first != "") print first }'
}

# Prints the chosen place of the agent $1: the setting when the agent has it, or else its first.
chosen_place() {
  printf '%s\n' "$all_ways" | awk -F '|' -v a="$1" -v want="$place" '$1 != a { next } first == "" { first = $3 } $3 == want { print $3; found = 1; exit } END { if (!found && first != "") print first }'
}

# Prints the column $3 of the way of the agent $1 at the place $2.
way_of() {
  printf '%s\n' "$all_ways" | awk -F '|' -v a="$1" -v p="$2" -v c="$3" '$1 == a && $3 == p { print $c; exit }'
}

# Prints the command of the agent $1.
bin_of() {
  printf '%s\n' "$known_agents" | awk -F '|' -v a="$1" '$1 == a { print $3; exit }'
}

# Prints the words of the button that sends to the agent. They are the same for a new spot and a change, and for every
# app, since the App row above already says where it works.
go_title() {
  printf 'Build'
}

# Prints the id of the button that starts the next run: a new one for each run, so that runs go on side by side.
next_key() {
  count=$(cat "$OPENSPOT_DATA/runs.count" 2>/dev/null || echo 0)
  if [ -n "$job" ]; then printf 'change-%s-%s' "$job" "$count"; else printf 'make-%s' "$count"; fi
}

# Prints an option of the agent choice for each agent on this Mac.
agent_options() {
  printf '%s\n' "$all_ways" | awk -F '|' '!seen[$1]++ { print $1 "|" $2 }' | while IFS='|' read -r key name; do
    printf '\noption=%s\n' "$key"
    openspot_kv title "$name"
  done
}

# Prints an option of the place choice for each place of the agent $1.
place_options() {
  printf '%s\n' "$all_ways" | awk -F '|' -v a="$1" '$1 == a { print $3 "|" $4 }' | while IFS='|' read -r id name; do
    printf '\noption=%s\n' "$id"
    openspot_kv title "$name"
  done
}

# Prints the field with the words $1, then the agent and where it works, then Copy prompt with the words $2 and the
# button that sends.
form() {
  me=$(chosen_agent)
  at=$(chosen_place "$me")
  go=
  [ -z "$at" ] || go=$(go_title "$me" "$at")
  printf '\nbox=form\nclass=flex-col gap-4 grow\n'
  printf '\nbox=top\nparent=form\nclass=flex-col gap-1 grow min-h-44\n'
  printf '\nfield=describe\nparent=top\ntype=multiline\nclass=grow\n'
  openspot_kv placeholder "$placeholder"
  openspot_kv value "$1"
  if [ -n "${looking-}" ]; then
    printf '\ntext=looking\nparent=top\nclass=text-secondary\ntitle=Finding agents…\n'
  elif [ -n "$go" ]; then
    printf '\nbox=with\nparent=top\nclass=flex-col gap-0\n'
    printf '\nchoice=agent\nparent=with\nclass=h-8\ntitle=Agent\nicon=sparkles\nvalue=%s\n' "$me"
    agent_options
    printf '\nchoice=place\nparent=with\nclass=h-8\ntitle=App\nicon=macwindow\nvalue=%s\n' "$at"
    place_options "$me"
    [ -z "${building-}" ] || builds_section
    printf '\nbox=go\nparent=form\nclass=flex-col gap-2 shrink-0\n'
    # A build in Openspot keeps the panel, which shows its progress. One in an app or a terminal hides it, since the work
    # goes on there.
    printf '\nbutton=%s\nparent=go\ntitle=%s\nclass=bg-accent\nshortcut=cmd+return\n' "$(next_key)" "$go"
    [ "$at" != openspot ] || printf 'close=false\n'
    printf '\nbutton=copy\nparent=go\ntitle=%s\nshortcut=cmd+shift+return\nclose=false\n' "${2:-Copy prompt}"
  else
    printf '\nbox=go\nparent=form\nclass=flex-row gap-2\n'
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
  put "$1" state stopped
}

# Prints the row of the running build $1 in the box $2: sparkles that grow star by star, its name over its step, and
# Stop, with the key $3 if any.
working() {
  printf '\nbox=run-%s\nparent=%s\nclass=flex-row items-center gap-2 py-1\n' "$1" "$2"
  printf '\nicon=run-%s-icon\nparent=run-%s\nvalue=sparkles\nclass=text-accent animate-pulse\n' "$1" "$1"
  printf '\ntext=run-%s-words\nparent=run-%s\nclass=grow\n' "$1" "$1"
  openspot_kv title "$(title_of "$1")"
  openspot_kv detail "$(get "$1" step)"
  printf '\nbutton=stop-%s\nparent=run-%s\ntitle=Stop\nicon=stop.fill\nclass=rounded-full bg-transparent sr-only\nclose=false\n' "$1" "$1"
  [ -z "$3" ] || printf 'shortcut=%s\n' "$3"
}

# Prints the Building section: a row for each running build, newest first. It gives up its height before the field
# does, and then its rows scroll under its head.
builds_section() {
  printf '\nbox=runs\nparent=form\nclass=flex-col gap-0\n'
  printf '\ntext=runs-head\nparent=runs\nclass=font-section text-secondary shrink-0\ntitle=Building\n'
  printf '\nbox=runs-list\nparent=runs\nclass=flex-col gap-0 overflow-y-auto\n'
  printf '%s\n' "$building" | while IFS= read -r dir; do working "$dir" runs-list; done
}

# Prints the builds that run now, the newest first.
running() {
  ls -1r "${builds:?}" 2>/dev/null | while IFS= read -r dir; do
    settle "$dir"
    [ "$(get "$dir" state)" = running ] && printf '%s\n' "$dir"
  done
}

# Prints the first sheet: the form of a new build, with the builds that run over its buttons. Each build shows on the
# Sessions page.
first_sheet() {
  printf 'frame=\nclass=gap-group animate-layout\n'
  building=$(running)
  form "$1" "$2"
  printf '\nbutton=sessions\ntitle=Sessions\nscope=spot\nshortcut=cmd+y\nclose=false\n'
  printf '\nbutton=folder\ntitle=Open spots folder\nscope=spot\n'
}

# Prints the button that deletes a build, after a second press.
delete_button() {
  printf '\nbutton=delete\ntitle=Delete\n%s\nshortcut=cmd+backspace\nconfirm=Press again to delete\nclose=false\n' "$1"
}

# Prints the page of the build $job: its step while it runs, then the spot it made and the form of the next change.
build_sheet() {
  settle "$job"
  state=$(get "$job" state)
  printf 'frame=%s\nclass=gap-group\n' "$route"
  if [ "$state" = running ]; then
    printf '\nbox=now\nclass=flex-col gap-0\n'
    working "$job" now cmd+return
    return
  fi
  edit=${OPENSPOT_EDIT-}
  if [ "$state" = failed ]; then
    printf '\nbox=made\nclass=flex-row items-center gap-2\n'
    printf '\nicon=made-icon\nparent=made\nvalue=exclamationmark.triangle.fill\nclass=text-bad\n'
    printf '\ntext=made-name\nparent=made\nclass=grow line-clamp-2\n'
    openspot_kv title "$(get "$job" said)"
    [ -n "$edit" ] || delete_button 'parent=made
class=rounded-full'
  elif [ -n "$spot" ] && [ -z "$edit" ] && [ "$state" != stopped ]; then
    printf '\nbox=made\nclass=flex-row items-center gap-2\n'
    printf '\nicon=made-icon\nparent=made\nvalue=checkmark.circle.fill\nclass=text-good\n'
    printf '\ntext=made-name\nparent=made\nclass=grow truncate\n'
    openspot_kv title "$spot"
    printf '\nbutton=open\nparent=made\ntitle=Open\nclass=rounded-full\nshortcut=cmd+o\nclose=false\n'
  fi
  form "$1" "$2"
  [ -n "$edit" ] || [ "$state" = failed ] || delete_button 'scope=spot'
}

# Prints the Sessions page: a row for each build, the running ones first, then the newest first. A row opens the
# build's page, and its menu opens the spot it made or deletes it.
sessions_page() {
  printf 'frame=sessions\nrecents=false\n'
  list=$(ls -1t "${builds:?}" 2>/dev/null | while IFS= read -r dir; do
    settle "$dir"
    [ -s "$builds/$dir/asked" ] || continue
    if [ "$(get "$dir" state)" = running ]; then printf '0 %s\n' "$dir"; else printf '1 %s\n' "$dir"; fi
  done | sort -s -k 1,1 | cut -d ' ' -f 2)
  [ -n "$list" ] || { printf '\ntext=empty\ntitle=No sessions yet\n'; return; }
  printf '%s\n' "$list" | while IFS= read -r dir; do
    state=$(get "$dir" state)
    case $state in
      running) icon=sparkles words=$(get "$dir" step) tone= ;;
      failed) icon=exclamationmark.triangle words=Failed tone=bad ;;
      stopped) icon=stop.circle words=Stopped tone= ;;
      *) icon=checkmark.circle words=Ready tone=good ;;
    esac
    printf '\nitem=%s\nicon=%s\nroute=build/%s\n' "$dir" "$icon" "$dir"
    openspot_kv title "$(name_of "$dir")"
    openspot_kv detail "$words"
    [ -z "$tone" ] || printf 'tone=%s\n' "$tone"
    [ -n "$(get "$dir" spot)" ] && [ "$state" = ready ] || printf 'hides=open-spot\n'
    [ "$state" != running ] || printf 'hides=delete\n'
  done
  printf '\nbutton=open-spot\ntitle=Open\nscope=item\nshortcut=cmd+o\n'
  delete_button 'scope=item'
}

sheet() {
  case $route in
    sessions | history) sessions_page ;;
    *) if [ -n "$job" ]; then build_sheet "$@"; else first_sheet "$@"; fi ;;
  esac
}

# Prints the prompt for the agent: to change the spot of this build, or to build a new one, as the words say.
prompt() {
  if [ -n "$spot" ]; then
    set -- "$spot" ${OPENSPOT_EDIT_FAILURE:+--failure "$OPENSPOT_EDIT_FAILURE"} ${1:+"$1"}
    openspot prompt change "$@"
  else
    openspot prompt new "$1"
  fi
}

# The words of the field: the ones on stdin when the sheet sends them, or else the draft that a last call kept. A draft
# that was copied or handed off is done, so the sheet opens empty.
case "$nl$(openspot_input)" in
  *"${nl}input.describe="*)
    typed=$(value input.describe; printf x)
    typed=${typed%x}
    # The words of a build that started are done, though the field still sends them until it draws again.
    if [ -f "$draft.sent" ] && [ "$typed" = "$(cat "$draft.sent")" ]; then
      typed=
    else
      rm -f "$draft.sent"
      openspot_keep "$draft" "$typed"
    fi
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
  # The Edit sheet of a spot hears no step of New spot, so its own run draws it again at each step.
  if [ -n "${OPENSPOT_EDIT-}" ]; then
    sheet ''
    printf -- '---\n'
    return
  fi
  printf 'frame=\nbackground=true\n'
  openspot_kv title "$work"
  [ -n "$was" ] || openspot_kv builds "$(get "$building" spot)"
  printf 'progress=%s\n\n---\n' "$1"
}

# Marks the spot of the new build $1 New, so that it shows first on the grid until people open it.
mark_new() {
  made=$(get "$1" spot)
  [ -n "$made" ] && [ -z "$was" ] || return 0
  said=$(openspot spot mark "$made" new 2>&1) || printf '%s %s: %s\n' "$(date +%T)" "$made" "$said" >> "$builds/$1/marks"
}

# Runs the agent $3 with no window for the build $1, with the prompt $4. Each step goes to the build's files and tells
# the sheet. The run itself prints only its title, its progress and the spot it builds, which Openspot hides while the
# run lasts, so Openspot shows no working card for it.
run() {
  building=$1
  bin=$(agent_bin "$3") || { echo "Openspot cannot find $3." >&2; exit 1; }
  mkdir -p "$folder" "${builds:?}/$1"
  log="$builds/$1/log"
  name=$(get "$1" spot)
  if [ -n "$(get "$1" change)" ]; then work="Changing $name…"; else work='Building a spot…'; fi
  put "$1" pid "$$"
  put "$1" state running
  trap 'put "$building" state stopped; moved "$building"; exit 0' TERM INT
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
  if [ -z "$failed" ] || [ "$failed" = true ] || [ ! -d "$folder/$name.spot" ]; then
    [ -n "$said" ] || said=$(tail -n 1 "$log")
    [ -d "$folder/$name.spot" ] || [ "$failed" = true ] || said='The agent is done, but made no spot.'
    [ -d "$folder/$name.spot" ] || rm -f "$builds/$1/spot" "$builds/$1/fresh"
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
  mark_new "$1"
  shown "$1" "$name"
  [ -z "${OPENSPOT_EDIT-}" ] || sheet ''
}

# Says that the spot $2 of the build $1 is ready. It waits on the grid, first and marked New, and opens only when people
# open it, so that the mark shows and nothing takes the panel.
shown() {
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

# Hands the words to the chosen agent where it works. Openspot starts a build: a new one from the first sheet, or the
# next change of the build whose page shows.
go() {
  text=$(trimmed)
  if [ -z "$text" ]; then
    openspot toast 'Describe it first.'
    sheet "$typed"
    return
  fi
  words=$(prompt "$text") || exit 1
  if [ -z "$job" ] && name=$(short "$text") && [ -n "$name" ]; then
    words="$words

Title the spot \"$name\" unless the words above name it."
  fi
  me=$(chosen_agent)
  at=$(chosen_place "$me")
  count=$(cat "$OPENSPOT_DATA/runs.count" 2>/dev/null || echo 0)
  openspot_keep "$OPENSPOT_DATA/runs.count" "$((count + 1))"
  rm -f "$draft" "$copied"
  case $at in
    openspot)
      was=$job
      [ -n "$job" ] || job="b$(date +%s)$$"
      if [ -n "$was" ]; then
        put "$job" change 1
      else
        rm -f "$builds/$job/change"
        made=$(free_id "$name")
        put "$job" spot "$made"
        put "$job" fresh 1
        words="$words

Build the spot in the folder $folder/$made.spot."
      fi
      openspot_keep "$draft.sent" "$typed"
      put "$job" asked "$(printf '%s' "$text" | tr '\n' ' ')"
      run "$job" "$1" "$(bin_of "$me")" "$words"
      ;;
    term-*)
      terminal "$(bin_of "$me")" "$(way_of "$me" "$at" 5)" "$words"
      openspot toast "Opened $(way_of "$me" "$at" 4)."
      sheet ""
      ;;
    app-*)
      in_app "$at" "$(way_of "$me" "$at" 5)" "$words"
      sheet ""
      ;;
    *)
      echo 'This Mac has no agent that New spot knows.' >&2
      exit 1
      ;;
  esac
}

[ -n "$all_ways" ] || [ "$1" = show ] || { all_ways=$(ways) && openspot_keep "$kept_ways" "$all_ways"; }

case "$1" in
  show)
    if [ -z "$all_ways" ]; then
      looking=1 sheet "$typed"
      looking=
    else
      sheet "$typed"
    fi
    printf -- '---\n'
    found=$(ways)
    [ "$found" != "$all_ways" ] || exit 0
    openspot_keep "$kept_ways" "$found"
    all_ways=$found
    sheet "$typed"
    ;;
  describe | new.step) sheet "$typed" ;;
  agent | place)
    chose=$(value input.value)
    [ -n "$chose" ] || exit 0
    openspot setting set "$1" "$chose" > /dev/null || exit 1
    if [ "$1" = agent ]; then agent=$chose; else place=$chose; fi
    sheet "$typed"
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
  sessions | history) openspot route push sessions --title Sessions > /dev/null ;;
  stop-*)
    # The row goes at once, and the run stops after the sheet shows without it, so that Stop never waits.
    dir=${1#stop-}
    case $dir in '' | */* | .*) exit 1 ;; esac
    put "$dir" state stopped
    sheet "$typed"
    printf -- '---\n'
    stop "$dir"
    ;;
  open) [ -z "$spot" ] || openspot spot push "$spot" > /dev/null ;;
  open-spot)
    made=$(get "$(value item)" spot)
    [ -z "$made" ] || openspot spot push "$made" > /dev/null
    ;;
  delete)
    # Delete drops a build, and the spot it began, if it never got ready, goes to the Trash, where ⌘Z brings it back.
    dir=$(value item)
    [ -n "$dir" ] || dir=$job
    case $dir in '' | */* | .*) exit 1 ;; esac
    settle "$dir"
    [ "$(get "$dir" state)" != running ] || { echo 'Stop this build first.' >&2; exit 1; }
    made=$(get "$dir" spot)
    if [ -n "$made" ] && [ -n "$(get "$dir" fresh)" ] && [ -d "$folder/$made.spot" ]; then
      openspot spot delete "$made" > /dev/null 2>&1 || true
    fi
    rm -rf "${builds:?}/$dir"
    if [ "$job" = "$dir" ]; then openspot route back > /dev/null 2>&1 || true; else sheet "$typed"; fi
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
    openspot guide --all > "$OPENSPOT_DATA/DOCS.md" && open "$OPENSPOT_DATA/DOCS.md"
    ;;
  folder)
    mkdir -p "$folder" && open "$folder"
    ;;
  *)
    echo 'New spot cannot do that.' >&2
    exit 1
    ;;
esac
