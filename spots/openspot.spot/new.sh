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
build=
case $route in build/*) build=${route#build/} ;; esac
case $build in */* | .*) build= ;; esac

# Prints the file $2 of the build $1, or nothing.
get() {
  cat "${builds:?}/$1/$2" 2>/dev/null
}

# Keeps $3 as the file $2 of the build $1.
put() {
  openspot_keep "${builds:?}/$1/$2" "$3"
}

# An agent that builds a spot reports each step with `openspot spot run openspot/new step build=<id> words=<step>`, and
# the card of its build shows the words.
if [ "$1" = step ]; then
  id=$(value input.build)
  case $id in '' | */* | .*) echo 'Name the build, such as build=b1795784144.' >&2; exit 2 ;; esac
  put "$id" step "$(value input.words | tr '\n' ' ' | cut -c 1-80)"
  exit 0
fi

# Says whether the spot $1 is a draft: its folder is there and its spot.toml says state = "draft". A draft is a spot
# that a build began and has not made yet.
is_draft() {
  grep -qE "^state *= *[\"']draft[\"']" "$folder/$1.spot/spot.toml" 2>/dev/null
}

# Prints the name a build goes by: the title of its spot once the agent has chosen it, so that people meet the spot by
# its name while it is built, or else the words sent, or else its id, cut to 40 letters.
title_of() {
  made=$(get "$1" spot)
  words=$(short "$(get "$1" asked)")
  title=$(sed -n 's/^title *= *"\(.*\)" *$/\1/p' "$folder/$made.spot/spot.toml" 2>/dev/null | head -n 1)
  printf '%s' "${title:-${words:-${made:-New spot}}}" | cut -c 1-40
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
  for id in $(ls -1t "${builds:?}" 2>/dev/null); do
    [ "$(get "$id" spot)" = "$1" ] && { printf '%s' "$id"; return; }
  done
}

if [ -n "${OPENSPOT_EDIT-}" ]; then
  build=$(build_of "$OPENSPOT_EDIT")
  if [ -z "$build" ]; then
    build="e$(date +%s)$$"
    put "$build" spot "$OPENSPOT_EDIT"
    put "$build" state ready
  fi
fi
spot=
[ -z "$build" ] || spot=$(get "$build" spot)
# A spot is made once its folder is there and it is no draft.
if [ -n "$spot" ] && [ -z "${OPENSPOT_EDIT-}" ]; then
  if [ ! -d "$folder/$spot.spot" ] || is_draft "$spot"; then spot=; fi
fi

if [ -n "$build" ]; then
  draft="$builds/$build/draft"
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
com.microsoft.VSCode	VS Code'

# The agents that New spot knows, each a key, the name people know it by, its command, the app it ships as, and the
# agent it runs as: claude or codex, which Openspot can run with no window.
known_agents='claude|Claude Code|claude|Claude|claude
codex|Codex|codex|Codex|codex
pi|Pi|pi||
gemini|Gemini CLI|gemini||
agy|Antigravity|agy||
kimi|Kimi|kimi||
opencode|opencode|opencode||
amp|Amp|amp||
cursor|Cursor|cursor-agent||
qwen|Qwen Code|qwen||
droid|Droid|droid||
copilot|Copilot|copilot||
goose|Goose|goose||
crush|Crush|crush||
aider|Aider|aider||'

# Prints the shell of the person when Openspot can run a line in it, or else zsh.
person_shell() {
  case ${SHELL-} in */zsh | */bash) printf '%s' "$SHELL" ;; *) printf /bin/zsh ;; esac
}

# Prints what the person's shell knows, as a terminal of theirs does: each of its aliases, and has <command> for each
# command of known_agents that it runs.
shell_look() {
  commands=$(printf '%s\n' "$known_agents" | cut -d '|' -f 3 | tr '\n' ' ')
  "$(person_shell)" -ic "alias; for c in $commands; do command -v \"\$c\" > /dev/null 2>&1 && echo \"has \$c\"; done" < /dev/null 2> /dev/null
}

# Prints an agent, in the form of known_agents and then its alias, for each alias in the look $1 that runs Claude Code
# or Codex, such as claude-personal for another account.
aliased() {
  printf '%s\n' "$1" | sed 's/^alias //' | while IFS='=' read -r word line; do
    case $word in '' | claude | codex | *[!A-Za-z0-9_.-]*) continue ;; esac
    kind=$(kind_of "$line")
    [ -z "$kind" ] || printf '%s|%s|%s||%s|%s\n' "$word" "$word" "$word" "$kind" "$word"
  done
}

# Prints claude or codex when the command line $1 runs Claude Code or Codex.
kind_of() {
  for each in claude codex; do
    printf ' %s ' "$1" | tr "'\"" '  ' | grep -q "[ /]$each " && { printf '%s' "$each"; return; }
  done
}

# Prints the terminals on this Mac, each followed by a space.
terminals() {
  for term in Ghostty iTerm Warp Terminal; do
    app_path "$term" > /dev/null && printf '%s ' "$term"
  done
}

# Prints the ways of the agent $1, named $2, that runs as $3 by the word $4: Openspot when it runs as Claude Code or
# Codex, then the way $5 when there is one, then each terminal of $terms.
agent_ways() {
  [ -z "$3" ] || printf '%s|%s|openspot|Openspot||%s|%s\n' "$1" "$2" "$3" "$4"
  [ -z "${5-}" ] || printf '%s\n' "$5"
  for term in $terms; do
    printf '%s|%s|term-%s|%s|%s|%s|%s\n' "$1" "$2" "$(slug "$term")" "$term" "$term" "$3" "$4"
  done
}

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

# Prints the word that runs the command $1 of an agent in the person's shell, as the look $2 found it: the command
# itself, or the path of the one inside the app that ships it, as Codex does. Fails when there is none.
agent_word() {
  printf '%s\n' "$2" | grep -qxF "has $1" && { printf '%s' "$1"; return; }
  [ "$1" = codex ] && ships=$(app_of Codex) && [ -x "$ships/Contents/Resources/codex-cli/bin/codex" ] &&
    { quote "$ships/Contents/Resources/codex-cli/bin/codex"; return; }
  return 1
}

# Prints a free id for a new spot from the words $1, such as log-run-distance, with a number after it when a spot or
# another build has it.
free_id() {
  base=$(printf '%s' "$1" | tr 'A-Z' 'a-z' | tr -c 'a-z0-9' ' ' | tr -s ' ' | sed 's/^ //; s/ $//' | tr ' ' '-')
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

# Prints each way this Mac can run an agent, one line each, which way_of reads: the agent, its name, the place, the
# place's name, what opens it, the agent it runs as and the word that runs it. A place is Openspot, a terminal, or an app that takes the prompt in a link: the agent's own, or an editor
# with Claude Code. An app that takes no prompt adds nothing to Copy prompt, so New spot leaves it out.
ways() {
  apps=$(installed_apps)
  look=$(shell_look)
  terms=$(terminals)
  printf '%s\n%s\n' "$known_agents" "$(aliased "$look")" | while IFS='|' read -r key name bin app kind word; do
    [ -n "$key" ] || continue
    [ -n "$word" ] || [ -z "$bin" ] || word=$(agent_word "$bin" "$look") || word=
    ships=
    [ -z "$app" ] || ships=$(app_of "$app") || ships=
    shipped=
    [ -z "$ships" ] || shipped=$(printf '%s|%s|app-%s|%s|%s' "$key" "$name" "$(slug "$app")" "$(basename "$ships" .app)" "$ships")
    if [ -n "$word" ]; then
      agent_ways "$key" "$name" "$kind" "$word" "$shipped"
    elif [ -n "$shipped" ]; then
      printf '%s\n' "$shipped"
    else
      continue
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

# Prints the ways of the command of the person's own from Settings, in the form of ways: each terminal, and Openspot
# when the command runs Claude Code or Codex. No look keeps them, so a change in Settings shows at once.
own_ways() {
  line=$(value setting.command)
  [ -n "$line" ] || return 0
  name=$(printf '%s' "$line" | awk '{ print $1 }')
  terms=$(terminals)
  agent_ways custom "${name##*/}" "$(kind_of "$line")" "$line"
}
own=$(own_ways)

# Prints each way: the kept ways of this Mac, then those of the person's own command.
ways_here() {
  printf '%s\n' "$all_ways"
  [ -z "$own" ] || printf '%s\n' "$own"
}

# The chosen agent and place, from the settings.
agent=$(value setting.agent)
place=$(value setting.place)

# Prints the chosen agent: the setting when this Mac still has it, or else the first.
chosen_agent() {
  ways_here | awk -F '|' -v want="$agent" 'NR == 1 { first = $1 } $1 == want { print $1; found = 1; exit } END { if (!found && first != "") print first }'
}

# Prints the chosen place of the agent $1: the setting when the agent has it, or else its first.
chosen_place() {
  ways_here | awk -F '|' -v a="$1" -v want="$place" '$1 != a { next } first == "" { first = $3 } $3 == want { print $3; found = 1; exit } END { if (!found && first != "") print first }'
}

# Prints the fact $3 of the way of the agent $1 at the place $2, or at any place that has it when $2 is empty: name,
# place-name, opens, kind (claude, codex or nothing) or word, the word that runs the agent in the person's shell.
way_of() {
  case $3 in name) c=2 ;; place-name) c=4 ;; opens) c=5 ;; kind) c=6 ;; word) c=7 ;; *) return 1 ;; esac
  ways_here | awk -F '|' -v a="$1" -v p="$2" -v c="$c" '$1 == a && (p == "" ? $c != "" : $3 == p) { print $c; found = 1; exit } END { exit !found }'
}

# Prints the id of the button that starts the next run: a new one for each run, so that runs go on side by side.
next_key() {
  count=$(cat "$OPENSPOT_DATA/runs.count" 2>/dev/null || echo 0)
  if [ -n "$build" ]; then printf 'change-%s-%s' "$build" "$count"; else printf 'make-%s' "$count"; fi
}

# Prints an option of the agent choice for each agent on this Mac, with its mark, or else the mark of the agent it runs
# as, in the ink of the appearance of macOS, since a menu draws a picture as it is.
agent_options() {
  case $(defaults read -g AppleInterfaceStyle 2>/dev/null) in Dark) ink=dark ;; *) ink=light ;; esac
  ways_here | awk -F '|' '!seen[$1]++ { print $1 "|" $2 }' | while IFS='|' read -r key name; do
    printf '\noption=%s\n' "$key"
    openspot_kv title "$name"
    for mark in "$key" "$(way_of "$key" '' kind)"; do
      [ -f "${0%/*}/logos/$ink/$mark.png" ] && { openspot_kv icon "${0%/*}/logos/$ink/$mark.png"; break; }
    done
  done
}

# Prints an option of the place choice for each place of the agent $1, with the icon of the app it opens.
place_options() {
  ways_here | awk -F '|' -v a="$1" '$1 == a { print $3 "|" $4 "|" $5 }' | while IFS='|' read -r id name opens; do
    printf '\noption=%s\n' "$id"
    openspot_kv title "$name"
    case $id in
      openspot) icon=$(command -v openspot) && icon=${icon%%.app/*}.app ;;
      term-*) icon=$(app_path "$opens") ;;
      *) icon=$opens ;;
    esac
    [ ! -d "$icon" ] || openspot_kv icon "$icon"
  done
}

# Prints the field with the words $1, then the agent and where it works, then Copy prompt with the words $2 and the
# button that sends. While it looks for the agents, the choices hold no option, so they spin, and the buttons are dimmed.
form() {
  me=$(chosen_agent)
  at=$(chosen_place "$me")
  printf '\nbox=form\nclass=flex-col gap-4\n'
  printf '\nbox=top\nparent=form\nclass=flex-col gap-1\n'
  printf '\nfield=describe\nparent=top\ntype=multiline\nclass=h-32\ngrow=false\n'
  openspot_kv placeholder "$placeholder"
  openspot_kv value "$1"
  if [ -n "${looking-}" ] || [ -n "$at" ]; then
    dim=
    [ -z "${looking-}" ] || dim=' opacity-40'
    printf '\nbox=with\nparent=top\nclass=flex-col gap-0\n'
    printf '\nchoice=agent\nparent=with\nclass=h-8\ntitle=Agent\nicon=sparkles\nvalue=%s\n' "$me"
    [ -n "${looking-}" ] || agent_options
    printf '\nchoice=place\nparent=with\nclass=h-8\ntitle=App\nicon=macwindow\nvalue=%s\n' "$at"
    [ -n "${looking-}" ] || place_options "$me"
    [ -z "${live-}" ] || builds_section
    printf '\nbox=go\nparent=form\nclass=flex-col gap-2 shrink-0\n'
    # A build in Openspot keeps the panel, which shows its progress. One in an app or a terminal hides it, since the work
    # goes on there.
    printf '\nbutton=%s\nparent=go\ntitle=Build\nclass=bg-accent%s\nshortcut=cmd+return\n' "$(next_key)" "$dim"
    [ "$at" != openspot ] && [ -z "${looking-}" ] || printf 'close=false\n'
    printf '\nbutton=copy\nparent=go\ntitle=%s\nshortcut=cmd+shift+return\nclose=false\n' "${2:-Copy prompt}"
    [ -z "$dim" ] || printf 'class=%s\n' "${dim# }"
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
  printf '%s\n' "$live" | while IFS= read -r id; do working "$id" runs-list; done
}

# Prints the builds that run now, the newest first.
running() {
  ls -1r "${builds:?}" 2>/dev/null | while IFS= read -r id; do
    settle "$id"
    [ "$(get "$id" state)" = running ] && printf '%s\n' "$id"
  done
}

# Prints the first sheet: the form of a new build, with the builds that run over its buttons. Each build shows on the
# Builds page.
first_sheet() {
  printf 'frame=\nclass=gap-group animate-layout\n'
  live=$(running)
  form "$1" "$2"
  printf '\nbutton=builds\ntitle=Builds\nscope=spot\nshortcut=cmd+y\nclose=false\n'
  printf '\nbutton=folder\ntitle=Open spots folder\nscope=spot\n'
}

# Prints the button that deletes a build, after a second press.
delete_button() {
  printf '\nbutton=delete\ntitle=Delete\n%s\nshortcut=cmd+backspace\nconfirm=Press again to delete\nclose=false\n' "$1"
}

# Prints the page of the build $build: its step while it runs, then the spot it made and the form of the next change.
build_sheet() {
  settle "$build"
  state=$(get "$build" state)
  printf 'frame=%s\nclass=gap-group\n' "$route"
  if [ "$state" = running ]; then
    printf '\nbox=now\nclass=flex-col gap-0\n'
    working "$build" now cmd+return
    return
  fi
  edit=${OPENSPOT_EDIT-}
  if [ "$state" = failed ]; then
    printf '\nbox=made\nclass=flex-row items-center gap-2\n'
    printf '\nicon=made-icon\nparent=made\nvalue=exclamationmark.triangle.fill\nclass=text-bad\n'
    printf '\ntext=made-name\nparent=made\nclass=grow line-clamp-2\n'
    openspot_kv title "$(get "$build" said)"
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

# Prints the Builds page: a row for each build, the running ones first, then the newest first. A row opens the
# build's page, and its menu opens the spot it made or deletes it.
builds_page() {
  printf 'frame=builds\nrecents=false\n'
  list=$(ls -1t "${builds:?}" 2>/dev/null | while IFS= read -r id; do
    settle "$id"
    [ -s "$builds/$id/asked" ] || continue
    if [ "$(get "$id" state)" = running ]; then printf '0 %s\n' "$id"; else printf '1 %s\n' "$id"; fi
  done | sort -s -k 1,1 | cut -d ' ' -f 2)
  [ -n "$list" ] || { printf '\ntext=empty\ntitle=No builds yet\n'; return; }
  printf '%s\n' "$list" | while IFS= read -r id; do
    state=$(get "$id" state)
    case $state in
      running) icon=sparkles words=$(get "$id" step) tone= ;;
      failed) icon=exclamationmark.triangle words=Failed tone=bad ;;
      stopped) icon=stop.circle words=Stopped tone= ;;
      *) icon=checkmark.circle words=Ready tone=good ;;
    esac
    printf '\nitem=%s\nicon=%s\nroute=build/%s\n' "$id" "$icon" "$id"
    openspot_kv title "$(title_of "$id")"
    openspot_kv detail "$words"
    [ -z "$tone" ] || printf 'tone=%s\n' "$tone"
    [ -n "$(get "$id" spot)" ] && [ "$state" = ready ] || printf 'hides=open-spot\n'
    [ "$state" != running ] || printf 'hides=delete\n'
  done
  printf '\nbutton=open-spot\ntitle=Open\nscope=item\nshortcut=cmd+o\n'
  delete_button 'scope=item'
}

sheet() {
  case $route in
    builds | history) builds_page ;;
    *) if [ -n "$build" ]; then build_sheet "$@"; else first_sheet "$@"; fi ;;
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

. "${0%/*}/build.sh"

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
  if [ -z "$spot" ] && name=$(short "$text") && [ -n "$name" ]; then
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
      [ -n "$build" ] || build="b$(date +%s)$$"
      if [ -z "$spot" ]; then
        made=$(get "$build" spot)
        if [ -z "$made" ]; then
          made=$(free_id "$name")
          put "$build" spot "$made"
        fi
        if [ ! -e "$folder/$made.spot/spot.toml" ]; then
          mkdir -p "$folder/$made.spot"
          printf 'state = "draft"\n' > "$folder/$made.spot/spot.toml"
        fi
        words="$words

$(draft_words "$folder/$made.spot")"
      fi
      words="$words

$(step_words "$build" "$(quote "$(command -v openspot)")")"
      openspot_keep "$draft.sent" "$typed"
      put "$build" asked "$(printf '%s' "$text" | tr '\n' ' ')"
      run "$build" "$1" "$me" "$words"
      ;;
    term-*)
      terminal "$me" "$(way_of "$me" "$at" opens)" "$words"
      openspot toast "Opened $(way_of "$me" "$at" place-name)."
      sheet ""
      ;;
    app-*)
      in_app "$at" "$(way_of "$me" "$at" opens)" "$words"
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
  builds | history) openspot route push builds --title Builds > /dev/null ;;
  stop-*)
    # The row goes at once, and the run stops after the sheet shows without it, so that Stop never waits.
    id=${1#stop-}
    case $id in '' | */* | .*) exit 1 ;; esac
    put "$id" state stopped
    sheet "$typed"
    printf -- '---\n'
    stop "$id"
    ;;
  open) [ -z "$spot" ] || openspot spot push "$spot" > /dev/null ;;
  open-spot)
    made=$(get "$(value item)" spot)
    [ -z "$made" ] || openspot spot push "$made" > /dev/null
    ;;
  delete)
    # Delete drops a build, and the spot it began, while it is still a draft, goes to the Trash, where ⌘Z brings it back.
    id=$(value item)
    [ -n "$id" ] || id=$build
    case $id in '' | */* | .*) exit 1 ;; esac
    settle "$id"
    [ "$(get "$id" state)" != running ] || { echo 'Stop this build first.' >&2; exit 1; }
    made=$(get "$id" spot)
    if [ -n "$made" ] && is_draft "$made"; then
      openspot spot delete "$made" > /dev/null 2>&1 || true
    fi
    rm -rf "${builds:?}/$id"
    if [ "$build" = "$id" ]; then openspot route back > /dev/null 2>&1 || true; else sheet "$typed"; fi
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
