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
| `toggle` | `<exec> state`, `<exec> on`, `<exec> off` | Prints `{"title":"Wi-Fi","subtitle":"Home","on":true}` for `state`. |
| `slider` | `<exec> state`, `<exec> <number>` | Prints `{"title":"Volume","level":40,"min":0,"max":100}` for `state`. |
| `list` | `<exec> items`, `<exec> <run>` | Prints one JSON line for each row, then runs the `run` value of the row you pick. |

## Lists

Each line of `items` is one row:

```json
{"title":"Safari","subtitle":"App","run":"/Applications/Safari.app","file":"/Applications/Safari.app"}
```

Only `title` and `run` are required. Also use `symbol` for an SF Symbol, `file` for a file's icon, or `image` for a
path to an image. `hides` is a list of action IDs that this row does not offer.

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

```json
{"title":"New note","fields":[{"name":"text","label":"Text","type":"multiline","value":"","required":true}]}
```

The type is `text` or `multiline`. `placeholder` is optional. Then `<exec> <id> [run]` gets the values as JSON on
stdin, and it can print the `run` value of the row to select.

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
refresh = 60

[[widgets]]
name = "Coffee today"
layout = "pair"
places = ["coffee/cups", "coffee/cups"]
```

File `coffee.sh`. Openspot calls `<exec> metric <name>`.

```sh
#!/bin/sh
echo '{"title":"3","detail":"Cups today","symbol":"cup.and.saucer.fill"}'
```

`refresh` is in seconds. The default is 60. Openspot reads a metric only when a widget places it and the panel is
open, so a metric costs nothing when the panel is closed. When a read fails, the last value stays and dims.

Each metric prints `title`, and can print `detail`, `symbol` and `tone`. The tone is `good`, `warn` or `bad`. Use it
only when the colour means something. Each kind has its own data:

| Kind | Shows | Also prints |
|---|---|---|
| `value` | A number or a word. | Nothing more. |
| `gauge` | A ring. | `"value":0.84`, from 0 to 1. |
| `trend` | A line. | `"points":[2,5,3,8]`. |
| `status` | A dot with a word. | Set `tone` for the colour of the dot. |
| `rows` | Short lines, as many as fit. | `"rows":[{"title":"Build","detail":"2m","tone":"good"}]`. |

## Widgets

A widget is a spot that shows metrics in a layout. It runs nothing, and it can place metrics of any plugin. So to make
your own widget, make a folder with only a manifest.

```toml
name = "My widgets"
api = 1

[[widgets]]
name = "Morning"
layout = "hero"
places = ["agents/list", "battery/level", "system/disk", "system/cpu"]
opens = "links/Links"
```

`places` fills the slots of the layout in order, and each slot needs one metric. `opens` is optional: it names the
command that Enter or a click runs. `key` also works.

| Layout | Size | Places |
|---|---|---|
| `hero` | 4x2 | One large on the left, two small over one wide on the right. |
| `quad` | 4x2 | Four wide, in two rows. |
| `pair` | 4x1 | Two wide. |
| `row` | 4x1 | Four small. |

A wide or large place shows a mark and its words. A small place shows only what fits: a ring holds its title, so keep
that title short, such as `84%`.

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
