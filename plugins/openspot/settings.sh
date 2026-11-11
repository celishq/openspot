#!/bin/sh
# title=Settings
# icon=gearshape
# detail=Choose your key
# size=small
# read=panel,sheet
# offers=search

# The spot and the key of a setting row, from setting:<spot>:<key>.
setting() {
  rest=${1#setting:}
  spot=${rest%%:*}
  key=${rest#*:}
}

# The spot and the command of a key row, from key:<spot>:<command>.
command() {
  rest=${1#key:}
  spot=${rest%:*}
  key=${rest##*:}
}

case "$1" in
  read)
    app=$(openspot app status) || exit 1
    spots=$(openspot spot list) || exit 1
    values=$(openspot setting list) || exit 1
    jq -n -r --argjson app "$app" --argjson spots "$spots" --argjson values "$values" '
      def esc: tostring | gsub("\\\\"; "\\\\") | gsub("\n"; "\\n");
      def block: to_entries | map(select(.value != null) | "\(.key)=\(.value | esc)") | "\n" + join("\n") + "\n";
      def keyrow($run; $title; $icon; $key; $spot):
        {row: $run, title: $title, detail: $spot.name, parent: $spot.name, icon: $icon,
         hides: (if $key then null else "clear" end), shortcut: ($key // "Record"), shake: true};
      def value($spot; $key): first($values[] | select(.spot == $spot and .key == $key) | .value) // null;
      def named: [$spots[] | .id as $id | .settings[] | {spot: $id, key: .id, title, icon}];
      def kept: [$values[] | select(.key != "" and (.key | test("\\s") | not))
        | . as $v | select([named[] | select(.spot == $v.spot and .key == $v.key)] | length == 0)
        | {spot, key, title: ((.key[0:1] | ascii_upcase) + .key[1:]), icon: null}];
      [{recents: false},
       {button: "open", title: "Change", close: false},
       {button: "clear", title: "Remove", shortcut: "cmd+backspace"},
       {row: "panel_key", title: "Open Openspot", icon: "keyboard", hides: "clear", shortcut: $app.panelKey},
       {row: "fix_key", title: "Open a fix", icon: "wrench.and.screwdriver", hides: "clear", shortcut: $app.fixKey}]
      + (if $app.login == null then [] else [{row: "open_at_login", title: "Open at login", icon: "power", value: $app.login}] end)
      + (if $app.link == null then [] else [{row: "command_link", title: "Use openspot in Terminal", detail: "The command line tool", icon: "terminal", value: $app.link}] end)
      + [$spots[] | select(.menubar) | {row: "menubar:\(.id)", title: "Show in the menu bar", detail: .name, parent: .name, icon, hides: "clear", value: .inMenuBar}]
      + [$spots[] | select(.float) | keyrow("float:\(.id)"; "Float"; .icon; .floatKey; .)]
      + [$spots[] | . as $s | .commands[] | keyrow("key:\($s.id):\(.id)"; .title; (.icon // $s.icon); .key; $s)]
      + [(named + kept)[] | . as $o | first($spots[] | select(.id == $o.spot)) // null | . as $s
         | value($o.spot; $o.key) as $v | ($s.name // $o.spot) as $name
         | {row: "setting:\($o.spot):\($o.key)", title: $o.title, detail: "\($name) · \($v // "Not set")", parent: $name,
            icon: ($o.icon // $s.icon // "gearshape"), hides: (if $v == null then "clear" else null end)}]
      | .[] | block'
    ;;
  open)
    case "$2" in
      open_at_login)
        if [ "$(openspot app status | jq -r '.login')" = true ]; then exec openspot app login off; else exec openspot app login on; fi
        ;;
      command_link)
        if [ "$(openspot app status | jq -r '.link')" = true ]; then
          openspot app link off && echo 'toast=Removed openspot'
        else
          openspot app link on && echo 'toast=Installed openspot'
        fi
        ;;
      menubar:*)
        id=${2#menubar:}
        spots=$(openspot spot list) || exit 1
        if [ "$(printf '%s' "$spots" | jq -r --arg id "$id" '.[] | select(.id == $id) | .inMenuBar')" = true ]; then
          exec openspot menubar off "$id"
        else
          exec openspot menubar on "$id"
        fi
        ;;
      setting:*)
        setting "$2"
        exec openspot setting change --spot "$spot" "$key"
        ;;
      *)
        echo 'Settings cannot do that.' >&2
        exit 1
        ;;
    esac
    ;;
  panel_key) exec openspot key set --panel "$2" ;;
  fix_key) exec openspot key set --fix "$2" ;;
  clear)
    case "$2" in
      setting:*) setting "$2"; exec openspot setting set --spot "$spot" "$key" ;;
      key:*) command "$2"; exec openspot key set "$spot" "$key" ;;
      float:*) exec openspot key set "${2#float:}" --float ;;
    esac
    ;;
  key:*) command "$1"; exec openspot key set "$spot" "$key" "$2" ;;
  float:*) exec openspot key set "${1#float:}" --float "$2" ;;
  *)
    echo 'Settings cannot do that.' >&2
    exit 1
    ;;
esac
