# Build an Openspot plugin

This guide is for people and for AI agents. It tells you all that you need.

A plugin is a folder in the plugins folder. The folder holds a `manifest.toml` and the scripts that it names.
Openspot reads the folder each time the panel opens, so a new plugin needs no restart.

The rule: a script prints data, and Openspot draws it. A plugin never draws.

## The smallest plugin

Folder `hello`, file `manifest.toml`:

```toml
name = "Hello"
api = 1

[[commands]]
name = "Hello"
exec = "run.sh"
symbol = "hand.wave"
subtitle = "Say hello"
```

File `run.sh`. Make it executable with `chmod +x run.sh`.

```sh
#!/bin/sh
say hello
```

## What a script prints

A script prints plain text, one `key=value` on each line. A blank line ends a block.

```text
title=Safari
subtitle=App
run=/Applications/Safari.app

title=Notes
run=/Applications/Notes.app
```

- A line splits at its first `=`, so a value can hold `=`, quotes and spaces.
- A line with no key, a key Openspot does not know and a value it cannot read are skipped.
- An empty value counts as no value.
- A value is one line. In a value, `\n` stands for a new line and `\\` for a backslash. If a value comes from outside your
  script, such as a file name or a web page, write its backslashes and new lines this way:
  `sed 's/\\/\\\\/g' | awk 'NR > 1 { printf "\\n" } { printf "%s", $0 }'`.
- With `jq -r`, use `def esc: gsub("\\\\"; "\\\\") | gsub("\n"; "\\n");` and write `"title=\(.title | esc)"`.

## Commands

A command is a spot in the grid. These are its keys:

| Key | Meaning |
|---|---|
| `name` | The title, and part of its ID: `<folder>/<name>`. Required. |
| `exec` | The script, in the plugin folder. Required. |
| `type` | `launch` (the default), `toggle`, `slider` or `list`. |
| `size` | `wide` (the default), `small`, `square` or `strip`. |
| `symbol` | An SF Symbol name. |
| `subtitle` | The second line. |
| `key` | One letter that runs it after the trigger key. |
| `state` | `true` when a list also prints a state. |

Openspot calls the script in these ways:

| Type | Call | The script does |
|---|---|---|
| `launch` | `<exec>` | Does the work. |
| `toggle` | `<exec> state`, `<exec> on`, `<exec> off` | Prints `title`, `subtitle` and `on=true` or `on=false` for `state`. |
| `slider` | `<exec> state`, `<exec> <number>` | Prints `title`, `level`, `min` and `max` for `state`. |
| `list` | `<exec> items`, `<exec> <run>` | Prints one block for each row, then runs the `run` value of the row you pick. |

## Lists

Each block of `items` is one row:

```text
title=Safari
subtitle=App
run=/Applications/Safari.app
file=/Applications/Safari.app
```

Only `title` and `run` are required. Also use `symbol` for an SF Symbol, `file` for a file's icon, or `image` for a
path to an image. `hides` is the ID of an action that this row does not offer. Repeat the line for each one.

More keys for a list command:

| Key | Meaning |
|---|---|
| `global` | `true` to show its rows in the main search. |
| `rank` | Its place in the main search. A lower number comes first, and no rank comes last. |
| `search` | `local` (the default): Openspot filters the rows. `live`: Openspot calls `<exec> items <text>`. |
| `pick` | `close` (the default) or `stay`, after a row is picked. |
| `recents` | `false` to not sort recent picks first. |
| `primary` | The word for Enter. The default is `Open`. |

## Actions and forms

An action is an extra thing to do. It shows in the ⌘K menu, and its key works directly.

```toml
[[actions]]
command = "Notes"
id = "copy"
title = "Copy"
key = "cmd+return"
```

| Key | Meaning |
|---|---|
| `command`, `id`, `title` | Required. The call is `<exec> <id> <run>`. |
| `key` | Such as `cmd+e`, `cmd+return` or `cmd+shift+d`. |
| `scope` | `item` (the default) or `command`, which needs no selected row. |
| `after` | `stay` (the default) or `close`. |
| `confirm` | Words that ask for a second press, such as `Press again to delete`. |
| `form` | `true` to ask for values first. |

For an action with a form, `<exec> form <id> [run]` prints the fields:

```text
title=New note
field=text
field.label=Text
field.type=multiline
field.required=true
```

Each `field` line starts a field, and it gives its name. A field needs a `field.label`. `field.type` is `text` (the
default) or `multiline`. `field.value` and `field.placeholder` are optional. Then `<exec> <id> [run]` gets the values on
stdin as one block, such as `text=one\ntwo`, and it can print the `run` value of the row to select.

## Metrics

A metric is one piece of live data. Any widget can show it. Its ID is `<folder>/<name>`.

Folder `coffee`, file `manifest.toml`:

```toml
name = "Coffee"
api = 1

[[metrics]]
name = "cups"
exec = "coffee.sh"
kind = "value"
label = "Cups today"
refresh = 60

[[widgets]]
name = "Coffee today"
layout = "pair"
places = ["coffee/cups", "coffee/cups"]
```

File `coffee.sh`. Openspot calls `<exec> metric <name>`.

```sh
#!/bin/sh
printf 'title=3\ndetail=Last at 14:20\nsymbol=cup.and.saucer.fill\n'
```

`refresh` is in seconds. The default is 60. Openspot reads a metric only when a widget places it and the panel is
open, or when a widget shows it in the menu bar. When a read fails, the last value stays and dims.

`label` says what the metric measures, and each place shows it. The default is the plugin's name.

Marks are white. A `tone` colours a mark to say what it means. `tint` also colours the mark, and it is optional: use red,
orange, yellow, green, mint, teal, cyan, blue, indigo, purple or pink, and only when the colour helps a person find one
metric among many. Text stays white.

Each metric prints `title`, its value, and can print `detail`, `symbol` and `tone`. Do not repeat the label in them.
The tone is `good`, `warn` or `bad`. Use it only when the colour means something. Each kind has its own data:

| Kind | Shows | Also prints |
|---|---|---|
| `value` | A number or a word. | Nothing more. |
| `gauge` | A ring. | `value=0.84`, from 0 to 1. |
| `trend` | Bars from zero. The last bar is the newest. | One `point=2` line for each bar, and `max=100` for a fixed top value. |
| `status` | A dot with a word. | Set `tone` for the colour of the dot. |
| `rows` | Short lines, as many as fit. | One `row=Build` line for each row, and after it `row.detail=2m` and `row.tone=good`. |

## Widgets

A widget is a spot that shows metrics in a layout. It runs nothing, and it can place metrics of any plugin. So to make
your own widget, make a folder with only a manifest.

```toml
name = "My widgets"
api = 1

[[widgets]]
name = "Morning"
layout = "hero"
places = ["agents/list", "battery/level", "system/cpu", "system/disk"]
opens = "links/Links"
```

`places` fills the slots of the layout in order, and each slot needs one metric. `opens` is optional: it names the
command that Enter or a click runs. `key` also works.

| Layout | Size | Places |
|---|---|---|
| `single` | 2x2 | One metric. Use `size` to ask for `small` (1x1) or `wide` (2x1). |
| `hero` | 4x2 | One large on the left, three lines on the right. |
| `pair` | 4x1 | Two, each with its mark at the outer edge. |
| `row` | 4x1 | Four values, each over its label. |

A size is a preference. The grid fills each row: four small spots stay 1x1, and fewer than four grow. The same is true
for a command with `size = "small"`, which shows only its symbol.

A large place shows the detail. In a `hero` line, a trend with `max` shows as one bar. Other places show only the label, the value and the mark, so keep the title short, such
as `84%`.

## The menu bar

Add `tray` to a widget to also show one of its metrics in the menu bar. It names one of the widget's `places`:
`tray = "coffee/cups"`. Openspot then reads that metric all the time, so choose a `refresh` that is not too short.

A click opens the panel on the command that `opens` names. A widget with no `opens` is selected in the panel instead.

The item shows the metric's `symbol` and its mark. A `rows` metric shows one count for each `row.tone`, worst first. A
`gauge` shows a small ring, a `trend` shows bars, a `status` shows a dot, and a `value` shows its title.

Print `hidden=true` to remove the item until the next read, such as when nothing is running. Widgets in the panel still
show the metric.

## Check your work

Run this before you stop. It loads each plugin and calls each state, list and metric once. It prints each fault, and
it exits with 1 when there is a fault.

```text
<path to Openspot> --check <plugins folder>
```

## Rules for scripts

- Print only the data. Send each message for the person to stderr. When a script fails, its last stderr line shows.
- Exit with 0 on success. Any other code is a failure.
- Be fast. A state has 2 seconds, a list or a metric has 10, and an action has 30.
- Keep files in `${OPENSPOT_CONFIG:-$HOME/.config/openspot}/data`, not in the plugin folder.
- Use short plain words in sentence case. Start an action's name with a verb.
- Do not use a `key` that another plugin has. The first plugin keeps it.
- A plugin runs with the full access of the person. If you are an agent, tell the person what yours runs.
