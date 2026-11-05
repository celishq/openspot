#!/bin/sh
# name=Plugins
# symbol=puzzlepiece.extension
# subtitle=Add your own
# key=p
# read=open
# recents=false
# order=1
export LC_ALL=en_US.UTF-8
here=$(cd "$(dirname "$0")" && pwd)
plugins=$(dirname "$here")
guide="$here/GUIDE.md"

case "$1" in
  "")
    printf 'action=new\ntitle=New plugin\nkey=cmd+n\nscope=command\nform=true\n\n'
    printf 'row=Copy prompt for AI\ndetail=Have an AI build a plugin for you\nrun=prompt\nsymbol=sparkles\n\n'
    printf 'row=Read the guide\ndetail=How plugins and widgets work\nrun=guide\nsymbol=book\n\n'
    printf 'row=Open plugins folder\ndetail=Add a script here to install a plugin\nrun=folder\nsymbol=folder\n'
    ;;
  open)
    case "$2" in
      prompt)
        pbcopy <<EOF
Build an Openspot plugin that does this: <describe what you want>

Read the guide first: $guide
Put the plugin in: $plugins
When it is ready, run this and fix each fault it reports: "$OPENSPOT_APP" --check "$plugins"
Tell me what the plugin runs on my computer.
EOF
        ;;
      guide)
        open "$guide"
        ;;
      folder)
        open "$plugins"
        ;;
    esac
    ;;
  form)
    printf 'title=New plugin\n\nfield=name\nlabel=Name\nrequired=true\nplaceholder=Weather\n'
    ;;
  new)
    name=$(sed -n 's/^name=//p')
    slug=$(printf '%s' "$name" | tr '[:upper:]' '[:lower:]' | tr -cs 'a-z0-9' '-' | sed 's/^-//; s/-$//')
    if [ -z "$slug" ]; then
      echo "Use letters or digits in the name." >&2
      exit 1
    fi
    file="$plugins/$slug.sh"
    if [ -e "$file" ] || [ -e "$plugins/$slug" ]; then
      echo "A plugin called $slug already exists." >&2
      exit 1
    fi
    cat > "$file" <<EOF
#!/bin/sh
# name=$name
# symbol=star
# subtitle=Edit $slug.sh
open -R "$file"
EOF
    chmod +x "$file"
    open -R "$file"
    ;;
  *)
    exit 1
    ;;
esac
