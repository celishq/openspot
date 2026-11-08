#!/bin/sh
# title=System Settings
# icon=gearshape
# detail=Open a setting
# read=panel
# global=true
export LC_ALL=en_US.UTF-8
panes="${SETTINGS_PANES:-/System/Library/ExtensionKit/Extensions}"
link='x-apple.systempreferences:'

# Prints the first language of the Mac as a folder name, such as en_GB.
language() {
  defaults read -g AppleLanguages 2>/dev/null | sed -n '2{s/[ ",]//g;s/-/_/g;p;}'
}

# Prints the rows of one pane and of its sections, in the first language that the pane has.
pane() {
  info="$1/Contents/Info.plist"
  [ "$(plutil -extract EXAppExtensionAttributes.EXExtensionPointIdentifier raw "$info" 2>/dev/null)" = com.apple.Settings.extension.ui ] || return 0
  terms='{}'
  for lang in "$full" "$base" en; do
    found=$(ls "$1/Contents/Resources/$lang.lproj/"*.searchTerms 2>/dev/null | head -1)
    [ -n "$found" ] && { terms=$(plutil -convert json -o - "$found" 2>/dev/null || echo '{}'); break; }
  done
  names=$(plutil -convert json -o - "$1/Contents/Resources/InfoPlist.loctable" 2>/dev/null || echo '{}')
  strings='{}'
  if grep -q sidebar-name "$info"; then
    strings=$(for table in "$1/Contents/Resources/"*.loctable; do plutil -convert json -o - "$table" 2>/dev/null; done \
      | jq -s -c --arg full "$full" --arg base "$base" 'map(.[$full] // .[$base] // .en // {}) | add // {}')
  fi
  plutil -convert json -o - "$info" | jq -r --arg app "$1" --arg link "$link" --arg settings "/System/Applications/System Settings.app" --arg full "$full" --arg base "$base" \
    --argjson names "$names" --argjson strings "$strings" --argjson terms "$terms" '
    def esc: gsub("\\\\"; "\\\\") | gsub("\n"; "\\n");
    . as $info
    | (($names[$full] // $names[$base] // $names.en // {}).CFBundleDisplayName) as $shown
    | (if $shown then [$shown]
       else [$info | .. | objects | select(has("sidebar-name"))] | sort_by(.predicate // "" | test("!=")) | map($strings[.["sidebar-name"]] // .["sidebar-name"])
       end) as $sidebar
    | (if ($sidebar | length) > 0 then $sidebar
       elif ($info.CFBundleDisplayName // "" | test("^[A-Z][a-z]+([A-Z][a-z]+)+$") | not) then [$info.CFBundleDisplayName]
       else [] end) as $titles
    | select($titles | length > 0)
    | (if ($info | has("CFBundleIcons") or has("CFBundleIconName")) then "icon=\($app)" else "icon=gearshape" end) as $icon
    | ($link + $info.CFBundleIdentifier) as $pane
    | ($titles[] | "row=\($pane)#\(esc)\ntitle=\(esc)\ndetail=System Settings\n\($icon)\nbadge=\($settings)\n"),
      ($terms | to_entries[] | .key as $anchor | (.value.localizableStrings // [])[]
        | select(.title != null and (.title | ascii_downcase) != ($titles[0] | ascii_downcase))
        | "row=\($pane)?\($anchor)#\(.title | esc)\ntitle=\(.title | esc)\ndetail=System Settings › \($titles[0] | esc)\n\($icon)\nbadge=\($settings)\n"
          + ((.index // "") | split(",") | map(gsub("^\\s+|\\s+$"; "")) | map(select(. != "")) | map("keyword=\(esc)\n") | join("")))'
}

case "$1" in
  read)
    full=$(language)
    base=${full%%_*}
    cache="$OPENSPOT_DATA/rows3-$(sw_vers -buildVersion 2>/dev/null)-$full"
    if [ ! -s "$cache" ]; then
      mkdir -p "$OPENSPOT_DATA"
      rm -f "$OPENSPOT_DATA"/rows*
      grep -l com.apple.Settings.extension.ui "$panes"/*.appex/Contents/Info.plist 2>/dev/null | while read -r info; do
        pane "${info%/Contents/Info.plist}"
      done > "$cache.$$" && mv "$cache.$$" "$cache"
    fi
    cat "$cache"
    ;;
  open)
    open "${2%%#*}"
    ;;
esac
