# Build an Openspot plugin

This guide is for people and for AI agents. It tells you all that you need.

A plugin is one executable file in the plugins folder, in any language. Openspot reads the folder each time the panel
opens, so a new plugin needs no restart.

The rule: a script prints data, and Openspot draws it. A plugin never draws.

## The smallest plugin

File `hello.sh`. Make it executable with `chmod +x hello.sh`.

```sh
#!/bin/sh
say hello
```

This is a spot called Hello. A click runs it. Openspot never runs a script only to look at it, unless its header says so.

Keep several scripts together in a folder if you want. Each executable file is one spot, and a file that is not
executable can hold shared code.

## The header

Comment lines right under the first line say what a script is, one `key=value` on each line. They can start with `#`,
`//` or `--`. The first other line ends them. Openspot reads them without running the script.

```sh
#!/bin/sh
# name=Morning
# symbol=sun.max
# subtitle=Start the day
# key=m
open -a Calendar
```

| Key | Meaning |
|---|---|
| `name` | The title. The default comes from the file name. |
| `symbol` | An SF Symbol name. |
| `subtitle` | The second line. |
| `key` | One letter that runs it after the trigger key. |
| `size` | `wide` (the default), `small`, `square` or `strip`. |
| `order` | Its place in the grid. A lower number comes first, and the default is 0. |
| `read` | When Openspot reads the script. See below. |
| `rank` | Shows its rows in the main search. A lower number comes first. Needs `read=open`. |
| `search` | `live`: Openspot calls `<script> search <text>`. Needs `read=click`. |
| `recents` | `false` to not sort recent picks first. |
| `tray` | `true` to show a metric in the menu bar. Needs a number as its `read`. |

To read a script, Openspot calls it with no arguments:

| `read` | Openspot reads it | Use it for |
|---|---|---|
| none | Never. A click runs it. | A script that does one thing. |
| `click` | On a click. | A list. |
| `open` | Each time the panel opens. | A toggle, a slider, or a list for the main search. |
| a number | Every that many seconds. | A metric. It has no spot unless it also has a `key`. |

So with a `read`, a script must do no work when it has no arguments.

## The calls

| Call | When | The script does |
|---|---|---|
| `<script>` | On a click or a read | Does its work, or prints what to show if it has a `read`. |
| `<script> open <run>` | A row is picked | Opens the row. |
| `<script> <action> [run]` | An action runs | Does it. A filled form comes on stdin. |
| `<script> form <action> [run]` | Before an action with a form | Prints the fields. |
| `<script> search <text>` | The search changes, with `search=live` | Prints the rows and the actions. |
| `<script> on`, `off` | A toggle is pressed | Turns it on or off. |
| `<script> level <number>` | A slider moves | Sets the level. |

## What a script prints

A script prints plain text, one `key=value` on each line. A blank line ends a block.

```text
row=Safari
detail=App
run=/Applications/Safari.app

row=Notes
run=/Applications/Notes.app
```

- A line splits at its first `=`, so a value can hold `=`, quotes and spaces.
- A line with no key, a key Openspot does not know and a value it cannot read are skipped.
- An empty value counts as no value.
- A value is one line. In a value, `\n` stands for a new line and `\\` for a backslash. If a value comes from outside your
  script, such as a file name or a web page, write its backslashes and new lines this way:
  `sed 's/\\/\\\\/g' | awk 'NR > 1 { printf "\\n" } { printf "%s", $0 }'`.
- With `jq -r`, use `def esc: gsub("\\\\"; "\\\\") | gsub("\n"; "\\n");` and write `"row=\(.title | esc)"`.

A block is a row when it has `row`, an action when it has `action`, and a form field when it has `field`. The first other
block says how the spot itself looks. Printing nothing means that there is nothing to show.

To confirm what an action did, print `toast=Saved`. Openspot shows it, also with the panel closed.

## Lists

A script that prints rows is a list. Each row is one block:

```text
row=Safari
detail=App
run=/Applications/Safari.app
file=/Applications/Safari.app
```

`row` and `run` are the only keys a list needs. Also use `symbol` for an SF Symbol, `file` for a file's icon, or `image`
for a path to an image. `hides` is the ID of an action that this row does not offer. Repeat the line for each one.

## Toggles and sliders

Give the script `read=open`, and let it print one block:

| Prints | Shows |
|---|---|
| `on=true` or `on=false` | A toggle. |
| `level=70`, and `min=0` and `max=100` | A slider. |

Both can print `title` and `detail`. The defaults come from the header.

## Actions and forms

An action is an extra thing to do. It shows in the ⌘K menu, and its key works directly. A list prints its actions with
its rows:

```text
action=copy
title=Copy
key=cmd+return
close=true
```

| Key | Meaning |
|---|---|
| `action`, `title` | Required. The call is `<script> <action> <run>`. |
| `key` | Such as `cmd+e`, `cmd+return` or `cmd+shift+d`. |
| `scope` | `command` for an action that needs no selected row. |
| `close` | `true` to close the panel after it runs. |
| `confirm` | Words that ask for a second press, such as `Press again to delete`. |
| `form` | `true` to ask for values first. |

`action=open` is special, because it sets what Enter does on a row. `title` is the word for Enter, and the default is
`Open`. `close=false` keeps the panel open after a pick.

For an action with a form, `<script> form <action> [run]` prints a block with the title, then one block for each field:

```text
title=New note

field=text
label=Text
type=multiline
required=true
```

A field needs `field`, its name, and `label`. `type` is `text` (the default) or `multiline`. `value` and `placeholder`
are optional. Then `<script> <action> [run]` gets the values on stdin as one block, such as `text=one\ntwo`, and it can
print the `run` value of the row to select.

## Sheets of parts

A script that prints parts opens a sheet of them, with no search field. Run `openspot catalog` for the whole language,
with examples. A model can write a good sheet from that text alone.

A sheet has a layout and parts. Use a named layout when one fits, because it gives the best result:

```text
layout=pair

part=input
cell=top
text=Hello

part=output
cell=bottom
text=Bonjour
readonly=true

part=swap
cell=swap
press=arrow.up.arrow.down
```

Or draw your own, with one letter for each area. A smaller area on a larger one floats, with its own background:

```text
grid=t t t t
grid=t t t c

part=note
cell=t
text=Buy milk
fill=true

part=save
cell=c
look=strong
press=checkmark
```

With no drawing, a sheet is one column of lines, and `section=<id>` starts a new group with a divider.

The app owns each gap, row height and centre. A script says only which part goes where, and cannot make an uneven sheet.

| Prints | Shows | Openspot calls |
|---|---|---|
| `title`, `detail`, `symbol` | A line, with a value on the right. | |
| `on=true` | A switch. | `set <id> true` or `false` |
| `level=70`, `min`, `max` | A slider. | `set <id> <number>` |
| `color=#ff0000` for each swatch, `value` | A row of colours. | `set <id> <color>` |
| `option=en:English` for each choice, `value` | A menu. | `set <id> <option id>` |
| `item=a:Address` for each row, `value` | A list to choose from. | `set <id> <item id>` |
| `text=...`, `placeholder` | A text area. `readonly=true` only shows the text. | `set <id> <text>` |
| `press=arrow.clockwise` | A round button. | `press <id>` |
| `press=true` | A button that fills its cell. | `press <id>` |
| `metric=42%`, `point=3`, `image=<path>`, `block=progress` | A number, a chart, a picture, a progress bar. | |
| `keys=7 8 9 +` in the layout block | A row of key buttons. | `press <word>` |

The script holds no state. Each call gets all values on stdin, as one block such as `input=one\ntwo`. It prints the
whole sheet again, or prints nothing to be read again. It can also print `toast=Saved`. In the layout block, `every=5`
reads an open sheet again every 5 seconds.

Openspot shows a change at once, and only the answer to the newest change shows. It waits for a pause in typing and in
a slider's motion. Text that the person is typing stays as typed until they press something.

To read the sheet when the panel opens, so that it opens at its full size, use `read=open`. Otherwise use `read=click`.

To try a sheet, run `openspot sandbox`, or `openspot sandbox <file>` to watch a file or run a script. It shows the real
sheet and its faults at once. `openspot check --sheet` reports the faults of a sheet on stdin, and `openspot render
<file.png>` draws it to a picture.

## The openspot command

A script finds `openspot` on its path. It gives what macOS has no command for, in plain text.

| Call | Does |
|---|---|
| `openspot check [folder]` | Reports the faults of a plugins folder. |
| `openspot check --sheet` | Reports the faults of a sheet on stdin. |
| `openspot catalog` | Prints the whole sheet language, with examples. |
| `openspot render <file.png>` | Draws the sheet on stdin to a picture. |
| `openspot sandbox [file]` | Opens a window to try a sheet from text, a file or a script. |
| `openspot color pick` | Prints the colour the person picks. Prints nothing on a cancel. |
| `openspot translate [--from code] [--to code]` | Translates the text on stdin on this Mac. Prints `text` and `from`, or `status=missing`, `unsupported` or `unknown`. |
| `openspot translate languages` | Prints each language, with its name. |

When macOS already has a command, use it: `pbcopy`, `open`, `say`, `caffeinate`, `mdfind`, `screencapture`,
`shortcuts run`, `osascript`. To decode a value from stdin, use `printf '%b' "$value"`.

To use `openspot` in a terminal, link it: `ln -s <path to Openspot.app>/Contents/Helpers/openspot /usr/local/bin/openspot`.

## Metrics

A metric is one piece of live data. Any widget can show it. A script with a number of seconds as its `read` is a metric,
and its ID is its path with no extension, such as `coffee` or `home/coffee`.

File `coffee.sh`:

```sh
#!/bin/sh
# name=Cups today
# symbol=cup.and.saucer.fill
# read=60
printf 'title=3\ndetail=Last at 14:20\n'
```

Openspot reads a metric only when a widget places it and the panel is open, or when a widget shows it in the menu bar.
When a read fails, the last value stays and dims.

`name` says what the metric measures, and each place shows it. Do not repeat it in the values. `symbol` can also be
printed, when it changes.

Marks are white. A `tone` colours a mark to say what it means: `good`, `warn` or `bad`. Use it only when the colour means
something. `tint` also colours the mark, and it is optional: use red, orange, yellow, green, mint, teal, cyan, blue,
indigo, purple or pink, and only when the colour helps a person find one metric among many. Text stays white.

What a metric prints decides how it shows:

| Prints | Shows |
|---|---|
| `title` | A number or a word. |
| `title` and `value=0.84`, from 0 to 1 | A ring. |
| `title` and one `point=2` line for each bar | Bars from zero. The last bar is the newest. `max=100` sets a fixed top value. |
| `title` and `tone`, with no `symbol` | A dot with a word. |
| A block with `row=Build` for each row | Short lines, as many as fit. Each can have `detail=2m` and `tone=good`. `title` is the count unless you print one. |

## Widgets

A widget is a spot that shows metrics in a layout. It runs nothing, and it can place metrics of any plugin. Widgets live
in a `.toml` file in the plugins folder:

```toml
[[widgets]]
name = "Morning"
layout = "hero"
places = ["agents", "battery", "cpu", "disk"]
opens = "links"
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
for a command with `size=small`, which shows only its symbol.

A large place shows the detail. In a `hero` line, a trend with `max` shows as one bar. Other places show only the label,
the value and the mark, so keep the title short, such as `84%`.

## The menu bar

Add `tray=true` to the header of a metric to show it in the menu bar. It needs no widget. Openspot then reads it all the
time, so choose a `read` that is not too short.

A click opens the panel on the metric's list if it also has a `key`. If not, the panel opens and selects a widget that
places it.

The item shows the metric's `symbol` and its mark. Rows show one count for each `tone`, worst first. A ring, bars and a
dot show small, and a `title` shows as text.

Print nothing to remove the item until the next read, such as when nothing is running. Widgets in the panel still show
the metric.

## Check your work

Run this before you stop. It loads each plugin and reads each one that has a `read`. It prints each fault, and it exits
with 1 when there is a fault. It does not run a script with no `read`.

```text
openspot check <plugins folder>
```

## Rules for scripts

- Print only the data. Send each message for the person to stderr. When a script fails, its last stderr line shows.
- Exit with 0 on success. Any other code is a failure.
- Be fast. A `read=open` that prints no rows has 2 seconds, a list or a metric has 10, and an action has 30.
- Keep files in `${OPENSPOT_CONFIG:-$HOME/.config/openspot}/data`, not in the plugin folder.
- Use short plain words in sentence case. Start an action's name with a verb.
- Do not use a `key` that another plugin has. The first plugin keeps it.
- A plugin runs with the full access of the person. If you are an agent, tell the person what yours runs.
