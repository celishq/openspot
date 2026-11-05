#!/bin/sh
export LC_ALL=en_US.UTF-8
here=$(cd "$(dirname "$0")" && pwd)
plugins=$(dirname "$here")
guide="$here/GUIDE.md"

case "$1" in
  items)
    printf 'title=Copy prompt for AI\nsubtitle=Have an AI build a plugin for you\nrun=prompt\nsymbol=sparkles\n\n'
    printf 'title=Read the guide\nsubtitle=How plugins and widgets work\nrun=guide\nsymbol=book\n\n'
    printf 'title=Open plugins folder\nsubtitle=Add a folder here to install a plugin\nrun=folder\nsymbol=folder\n'
    ;;
  prompt)
    pbcopy <<EOF
Build an Openspot plugin that does this: <describe what you want>

Read the guide first: $guide
Put the plugin in its own folder in: $plugins
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
  form)
    printf 'title=New plugin\nfield=name\nfield.label=Name\nfield.required=true\nfield.placeholder=Weather\n'
    ;;
  new)
    name=$(sed -n 's/^name=//p')
    slug=$(printf '%s' "$name" | tr '[:upper:]' '[:lower:]' | tr -cs 'a-z0-9' '-' | sed 's/^-//; s/-$//')
    if [ -z "$slug" ]; then
      echo "Use letters or digits in the name." >&2
      exit 1
    fi
    folder="$plugins/$slug"
    if [ -e "$folder" ]; then
      echo "A plugin called $slug already exists." >&2
      exit 1
    fi
    mkdir -p "$folder"
    title=$(printf '%s' "$name" | sed 's/["\\]//g')
    cat > "$folder/manifest.toml" <<EOF
name = "$title"
api = 1

[[commands]]
name = "$title"
exec = "$slug.sh"
symbol = "star"
subtitle = "Edit $slug.sh"
EOF
    cat > "$folder/$slug.sh" <<EOF
#!/bin/sh
open "$folder"
EOF
    chmod +x "$folder/$slug.sh"
    open "$folder"
    ;;
  *)
    exit 1
    ;;
esac
