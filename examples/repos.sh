#!/bin/sh
# icon=arrow.triangle.branch
# detail=Open a git repo
# on=sheet.open
# uses=clipboard
#
# field=folder
#
# field=editor
# title=Default app
export LC_ALL=en_US.UTF-8
. "$OPENSPOT_SH"
editors='Visual Studio Code
Cursor
Zed
Windsurf
Sublime Text
Nova
BBEdit
TextMate
Xcode
IntelliJ IDEA
IntelliJ IDEA CE
WebStorm
PyCharm
PyCharm CE
GoLand
RustRover
Fleet
Android Studio'
finder=/System/Library/CoreServices/Finder.app

folder=$(openspot setting get folder)
editor=$(openspot setting get editor)
[ -d "$folder" ] || folder=""
[ -d "$editor" ] || editor=""

# Prints the path of each editor on this Mac, one a line, then Finder. APP_FOLDERS names where to look, in order, as PATH does.
installed() {
  printf '%s\n' "$editors" | while IFS= read -r name; do
    IFS=:
    for place in ${APP_FOLDERS:-$HOME/Applications:/Applications}; do
      if [ -d "$place/$name.app" ]; then
        printf '%s\n' "$place/$name.app"
        break
      fi
    done
  done
  printf '%s\n' "$finder"
}

# Prints the name of an app from its path.
name() {
  app=${1##*/}
  printf '%s' "${app%.app}"
}

# Prints the folder of a repo's git data. The .git of a worktree or a submodule is a file that names it.
git_dir() {
  git=$1/.git
  if [ -f "$git" ]; then
    read -r line < "$git"
    git=${line#gitdir: }
    case "$git" in
      /*) ;;
      *) git=$1/$git ;;
    esac
  fi
  printf '%s' "$git"
}

# Prints the branch that a repo has out, or the start of its commit when it has none.
branch() {
  read -r head < "$(git_dir "$1")/HEAD" 2>/dev/null || return 0
  case "$head" in
    "ref: refs/heads/"*) printf '%s' "${head#ref: refs/heads/}" ;;
    *) printf '%.7s' "$head" ;;
  esac
}

# Prints the form that asks for the editor, with this title.
form() {
  openspot_kv title "$1"
  printf '\nchoice=editor\ntitle=Default app\n'
  openspot_kv value "$editor"
  installed | while IFS= read -r app; do
    printf '\n'
    openspot_kv option "$app"
    openspot_kv title "$(name "$app")"
  done
}

# Keeps the editor of the form. Asks again when the form gave an app that is gone, and returns 1 then.
keep_editor() {
  chosen=$(value editor)
  if [ ! -d "$chosen" ]; then
    form "Openspot cannot find that app. Choose another one."
    return 1
  fi
  openspot setting set editor "$chosen" || exit 1
  editor=$chosen
}

[ -n "$editor" ] || editor=$(installed | head -n 1)

# Asks for the folder of the repos, and keeps it. Cancel keeps the folder that was there.
pick_folder() {
  picked=$(openspot folder pick) || exit 1
  [ -z "$picked" ] || openspot setting set folder "$picked"
}

# Prints the web page of a repo's remote origin, or else of its first remote. Prints nothing for a remote with no page.
page() {
  git=$(git_dir "$1")
  if [ -f "$git/commondir" ]; then
    read -r common < "$git/commondir"
    case "$common" in
      /*) git=$common ;;
      *) git=$git/$common ;;
    esac
  fi
  url=$(awk '
    /^[[:space:]]*\[/ { remote = /^[[:space:]]*\[remote "/; origin = /"origin"/; next }
    remote && /^[[:space:]]*url[[:space:]]*=/ {
      sub(/^[^=]*=[[:space:]]*/, "")
      if (origin) { print; done = 1; exit }
      if (first == "") first = $0
    }
    END { if (!done && first != "") print first }
  ' "$git/config" 2>/dev/null)
  case "$url" in
    http://* | https://*) rest=${url#*://} keep=port ;;
    ssh://* | git://*) rest=${url#*://} keep="" ;;
    *@*:*) rest=${url#*@} keep="" && rest=${rest%%:*}/${rest#*:} ;;
    *) return 0 ;;
  esac
  host=${rest%%/*}
  path=${rest#"$host"}
  host=${host#*@}
  [ -n "$keep" ] || host=${host%%:*}
  path=${path%/}
  path=${path%.git}
  [ -n "$host" ] && [ -n "${path#/}" ] && printf 'https://%s%s' "$host" "$path"
}

# Prints the name of a web host, such as GitHub for github.com.
site() {
  case "$1" in
    github.com) printf 'GitHub' ;;
    gitlab.com) printf 'GitLab' ;;
    bitbucket.org) printf 'Bitbucket' ;;
    *) printf '%s' "$1" ;;
  esac
}

# Prints the host of a web page.
host() {
  rest=${1#https://}
  printf '%s' "${rest%%/*}"
}

tab=$(printf '\t')

case "$1" in
  read)
    if [ -z "$folder" ]; then
      printf 'button=open\ntitle=Choose\n\n'
      printf 'row=choose\ntitle=Choose the folder of your repos\ndetail=Repos lists each git repo inside it\nicon=folder.badge.plus\n'
      exit 0
    fi
    repos=""
    for repo in "$folder"/*/; do
      repo=${repo%/}
      [ -e "$repo/.git" ] || continue
      repos="$repos$repo$tab$(page "$repo")
"
    done
    hosts=$(printf '%s' "$repos" | while IFS="$tab" read -r repo url; do [ -z "$url" ] || host "$url"; echo; done | sed '/^$/d' | sort -u)
    printf 'button=open\n'
    openspot_kv title "Open in $(name "$editor")"
    printf '\n'
    index=0
    installed | while IFS= read -r app; do
      index=$((index + 1))
      [ "$app" = "$editor" ] || [ "$app" = "$finder" ] || { printf 'button=in-%s\nclose=true\n' "$index"; openspot_kv title "Open in $(name "$app")"; printf '\n'; }
    done
    index=0
    printf '%s\n' "$hosts" | while IFS= read -r each; do
      [ -n "$each" ] || continue
      index=$((index + 1))
      printf 'button=page-%s\nclose=true\n' "$index"
      openspot_kv title "Open on $(site "$each")"
      printf '\n'
    done
    printf 'button=reveal\ntitle=Show in Finder\nshortcut=cmd+return\nclose=true\n\n'
    printf 'button=terminal\ntitle=Open in Terminal\nshortcut=cmd+t\nclose=true\n\n'
    printf 'button=copy\ntitle=Copy path\nshortcut=cmd+shift+c\nclose=true\n\n'
    printf 'button=editor\ntitle=Change default app\nscope=spot\nform=true\n\n'
    printf 'button=folder\ntitle=Change folder\nscope=spot\nclose=true\n\n'
    printf '%s' "$repos" | while IFS="$tab" read -r repo url; do
      openspot_row "$repo" "${repo##*/}" "$(branch "$repo")" "$repo"
      own=$( [ -z "$url" ] || host "$url")
      index=0
      printf '%s\n' "$hosts" | while IFS= read -r each; do
        [ -n "$each" ] || continue
        index=$((index + 1))
        [ "$each" = "$own" ] || printf 'hides=page-%s\n' "$index"
      done
      printf '\n'
    done
    if [ -z "$repos" ]; then
      shown=$folder
      case "$shown" in
        "$HOME"/*) shown="~${shown#"$HOME"}" ;;
      esac
      openspot_row choose "No git repos in $shown" "Choose another folder" folder.badge.questionmark
    fi
    ;;
  open)
    if [ "$2" = choose ]; then
      pick_folder
      exit 0
    fi
    open -a "$editor" "$2"
    ;;
  page-*)
    open "$(page "$2")"
    ;;
  in-*)
    app=$(installed | sed -n "${1#in-}p")
    open -a "$app" "$2"
    ;;
  editor)
    if [ -z "$(value editor)" ]; then
      form "Choose the default app"
      exit 0
    fi
    keep_editor
    ;;
  folder)
    pick_folder
    ;;
  reveal)
    open -R "$2"
    ;;
  terminal)
    open -a Terminal "$2"
    ;;
  copy)
    printf '%s' "$2" | pbcopy
    echo "toast=Copied"
    ;;
esac
