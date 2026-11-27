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
dev.zed.Zed	Zed
com.microsoft.VSCode	VS Code'

# The agents that New spot knows, each a key, the name people know it by, its command, the app it ships as, yes when
# Openspot can run it with no window, and the agent it runs as: claude or codex.
known_agents='claude|Claude Code|claude|Claude|yes|claude
codex|Codex|codex|Codex|yes|codex
gemini|Gemini CLI|gemini|||
opencode|opencode|opencode|||
amp|Amp|amp|||
cursor|Cursor|cursor-agent|||'

# Prints the shell of the person when Openspot can run a line in it, or else zsh.
person_shell() {
  case ${SHELL-} in */zsh | */bash) printf '%s' "$SHELL" ;; *) printf /bin/zsh ;; esac
}

# Prints an agent, in the form of known_agents and then its alias, for each alias of the person's shell that runs
# Claude Code or Codex, such as claude-personal for another account.
aliased() {
  "$(person_shell)" -ic alias < /dev/null 2> /dev/null | sed 's/^alias //' | while IFS='=' read -r word line; do
    case $word in '' | claude | codex | *[!A-Za-z0-9_.-]*) continue ;; esac
    for kind in claude codex; do
      printf ' %s ' "$line" | tr "'\"" '  ' | grep -q "[ /]$kind " || continue
      printf '%s|%s|%s||yes|%s|%s\n' "$word" "$word" "$word" "$kind" "$word"
      break
    done
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

# Prints each way this Mac can run an agent, one line each: the agent, its name, the place, the place's name and what
# opens it. A place is Openspot, a terminal, or an app that takes the prompt in a link: the agent's own, or an editor
# with Claude Code. An app that takes no prompt adds nothing to Copy prompt, so New spot leaves it out.
# Each line also names the agent it runs as and, for an alias, the alias.
ways() {
  apps=$(installed_apps)
  printf '%s\n%s\n' "$known_agents" "$(aliased)" | while IFS='|' read -r key name bin app here kind word; do
    [ -n "$key" ] || continue
    has_bin=
    if [ -n "$word" ]; then
      has_bin=1
    elif [ -n "$bin" ] && agent_bin "$bin" > /dev/null; then
      has_bin=1
    fi
    own=
    [ -z "$app" ] || own=$(app_of "$app") || own=
    [ -n "$has_bin" ] || [ -n "$own" ] || continue
    if [ -n "$has_bin" ]; then
      [ -z "$here" ] || printf '%s|%s|openspot|Openspot||%s|%s\n' "$key" "$name" "$kind" "$word"
    fi
    [ -z "$own" ] || printf '%s|%s|app-%s|%s|%s\n' "$key" "$name" "$(slug "$app")" "$(basename "$own" .app)" "$own"
    if [ -n "$has_bin" ]; then
      for term in Ghostty iTerm Warp Terminal; do
        app_path "$term" > /dev/null && printf '%s|%s|term-%s|%s|%s|%s|%s\n' "$key" "$name" "$(slug "$term")" "$term" "$term" "$kind" "$word"
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

# Prints the agent that the agent $1 runs as: claude, codex or nothing.
kind_of() {
  printf '%s\n%s\n' "$known_agents" "$all_ways" | awk -F '|' -v a="$1" '$1 == a && $6 != "" { print $6; exit }'
}

# Prints the command word of the agent $1 for the person's shell: its alias, or else the path of its command, quoted.
command_of() {
  word=$(printf '%s\n' "$all_ways" | awk -F '|' -v a="$1" '$1 == a && $7 != "" { print $7; exit }')
  [ -z "$word" ] || { printf '%s' "$word"; return; }
  path=$(agent_bin "$(printf '%s\n' "$known_agents" | awk -F '|' -v a="$1" '$1 == a { print $3; exit }')") || return 1
  quote "$path"
}

# Prints the words of the button that sends to the agent. They are the same for a new spot and a change, and for every
# app, since the App row above already says where it works.
go_title() {
  printf 'Build'
}

# Prints the id of the button that starts the next run: a new one for each run, so that runs go on side by side.
next_key() {
  count=$(cat "$OPENSPOT_DATA/runs.count" 2>/dev/null || echo 0)
  if [ -n "$build" ]; then printf 'change-%s-%s' "$build" "$count"; else printf 'make-%s' "$count"; fi
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
    [ -z "${live-}" ] || builds_section
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
      terminal "$me" "$(way_of "$me" "$at" 5)" "$words"
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
