#!/bin/sh
# icon=arrow.triangle.branch
# detail=Open a git repo
# shortcut=r
# size=small
# read=sheet
# settings=folder,editor
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

# Prints the branch that a repo has out, or the start of its commit when it has none.
branch() {
  git=$1/.git
  if [ -f "$git" ]; then
    read -r line < "$git"
    git=${line#gitdir: }
    case "$git" in
      /*) ;;
      *) git=$1/$git ;;
    esac
  fi
  read -r head < "$git/HEAD" 2>/dev/null || return 0
  case "$head" in
    "ref: refs/heads/"*) printf '%s' "${head#ref: refs/heads/}" ;;
    *) printf '%.7s' "$head" ;;
  esac
}

# Prints the form that asks for the editor, with this title.
form() {
  printf 'title=%s\n\nchoice=editor\ntitle=Editor\nvalue=%s\n' "$1" "$(esc "$editor")"
  installed | while IFS= read -r app; do
    printf 'option=%s:%s\n' "$(esc "$app")" "$(esc "$(name "$app")")"
  done
}

# Keeps the editor of the form. Asks again when the form gave an app that is gone, and returns 1 then.
keep_editor() {
  chosen=$(value editor)
  if [ ! -d "$chosen" ]; then
    form "Openspot cannot find that app. Choose another editor."
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

case "$1" in
  read)
    if [ -z "$folder" ]; then
      printf 'button=open\ntitle=Choose\n\n'
      printf 'row=choose\ntitle=Choose the folder of your repos\ndetail=Repos lists each git repo inside it\nicon=folder.badge.plus\n'
      exit 0
    fi
    printf 'button=open\ntitle=Open in %s\n\n' "$(esc "$(name "$editor")")"
    index=0
    installed | while IFS= read -r app; do
      index=$((index + 1))
      [ "$app" = "$editor" ] || [ "$app" = "$finder" ] || printf 'button=in-%s\ntitle=Open in %s\nclose=true\n\n' "$index" "$(esc "$(name "$app")")"
    done
    printf 'button=reveal\ntitle=Show in Finder\nshortcut=cmd+return\nclose=true\n\n'
    printf 'button=terminal\ntitle=Open in Terminal\nshortcut=cmd+t\nclose=true\n\n'
    printf 'button=copy\ntitle=Copy path\nshortcut=cmd+shift+c\nclose=true\n\n'
    index=0
    installed | while IFS= read -r app; do
      index=$((index + 1))
      [ "$app" = "$editor" ] || printf 'button=use-%s\ntitle=Use %s by default\nscope=command\nclose=false\n\n' "$index" "$(esc "$(name "$app")")"
    done
    printf 'button=folder\ntitle=Change folder\nscope=command\nclose=true\n\n'
    found=0
    for repo in "$folder"/*/; do
      repo=${repo%/}
      [ -e "$repo/.git" ] || continue
      found=1
      printf 'row=%s\ntitle=%s\ndetail=%s\nicon=%s\n\n' "$(esc "$repo")" "$(esc "${repo##*/}")" "$(esc "$(branch "$repo")")" "$(esc "$repo")"
    done
    if [ "$found" = 0 ]; then
      shown=$folder
      case "$shown" in
        "$HOME"/*) shown="~${shown#"$HOME"}" ;;
      esac
      printf 'row=choose\ntitle=No git repos in %s\ndetail=Choose another folder\nicon=folder.badge.questionmark\n' "$(esc "$shown")"
    fi
    ;;
  open)
    if [ "$2" = choose ]; then
      pick_folder
      exit 0
    fi
    open -a "$editor" "$2"
    ;;
  in-*)
    app=$(installed | sed -n "${1#in-}p")
    open -a "$app" "$2"
    ;;
  use-*)
    openspot setting set editor "$(installed | sed -n "${1#use-}p")"
    ;;
  editor)
    if [ -z "$(value editor)" ]; then
      form "Choose an editor"
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
