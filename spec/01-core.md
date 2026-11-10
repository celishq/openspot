# 01 Core

`final` `required`

```text
<script> read [text]          safe: show what you have
<script> <id> [value]...      act: something happened to this id
values on stdin               frames of key=value blocks on stdout
```

A plugin is one executable file, in any language, at the top of the plugins folder or one folder down. One file gives
at most one spot, and its ID is its path with no extension, such as `home/coffee`. A file that is not executable
can hold shared code.

A plugin of more than one file lives in a folder of its own, one folder down, such as a script with its view or a widget
with its metrics (F10). The folder is one unit: it is shared whole, and its scripts share one data folder.

```sh
#!/bin/sh
say hello
```

This is a spot called Hello, and a click runs it. A Swift file with `#!/usr/bin/env swift` on its first line is a script
too, with its header in `//` lines. It needs the Command Line Tools on the Mac that runs it.

## The format

A line is `key=value`, and it splits at its first `=`. A blank line ends a block, and a line `---` ends a frame. In a
value, `\n` stands for a new line and `\\` for a backslash. These are the only escapes. An empty value counts as no value.

The first key of a block names its kind. The one block whose first key names no kind is the head, which says how the
spot looks (02). A line with an unknown key is skipped. Printing nothing means that there is nothing to show. `toast=Saved` in the head shows at once, also with the panel
closed.

## The header

Comment lines right under the first line say what a script is, one `key=value` on each line. They start with `#`, `//` or
`--`, and the first other line ends them. A scan reads them and never runs a script. A header key that is not valid
refuses that plugin, and the others still load.

```sh
#!/bin/sh
# title=Morning
# icon=sun.max
# shortcut=m
open -a Calendar
```

| Key                      | Meaning                                                                                                                                                              |
| ------------------------ | -------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `title`                  | The title. The default comes from the file name.                                                                                                                     |
| `icon`                   | Its picture, as in 02. A path that does not start with `/` starts at the folder of the script.                                                                       |
| `detail`                 | The second line.                                                                                                                                                     |
| `shortcut`               | One letter. Hold the key that opens the panel, and press this letter to run it.                                                                                      |
| `size`                   | The size it prefers: `wide` (the default), `small`, `square`, `strip` or `large`. The grid can change it.                                                            |
| `read`                   | The moments when Openspot reads the script.                                                                                                                          |
| `data`                   | The name of a data folder to share with other spots.                                                                                                                 |
| `drop`                   | The files that its card takes: extensions such as `mov,mkv`, `folder`, or `*`.                                                                                       |
| `command`                | `<id>:<title>[:<icon>]`, a command that the person can give a key. One line for each.                                                                                  |
| `view`                   | A SwiftUI file beside the script, such as `view=cups.swift` (03).                                                                                                    |
| `global`                 | `true` shows its rows in the main search too. `rows` shows its rows there, but not the spot itself. It needs `panel`, `launch` or a number in its `read`, and a number also needs a `shortcut`. Openspot ranks the rows by the person's picks. With no `shortcut`, the spot has no card on the grid until the person places one. |
| `tray`                   | `true` shows its main value in the menu bar. It needs a number in its `read`. Printing nothing removes the item until the next read. |
| `settings`               | The values that the person chooses for it, each as `<key>[:<title>[:<icon>]]`, such as `folder,editor:Default app`. Settings lists each one, and Enter there runs the action of the same key. |
| `stay`                   | `true` keeps one process that takes each call on stdin and prints frames at any time (05).                                                                           |
| `press`                  | `run` makes Enter and a click on its card call `<script> run`, also when it has a sheet. With ⌥, they open the sheet. `sheet`, the default, opens it. |

With `panel` in its `read`, the head of a frame can change `size`. The person's choice wins (F9). A script with `command`
lines has no card on the grid, because its commands are what it gives.

## Moments

`read` lists moments, split by commas, such as `read=panel,60`. At each moment Openspot calls `<script> read`.

| Moment   | Openspot reads it                                      |
| -------- | ------------------------------------------------------ |
| none     | Never. A click runs `<script> run`.                    |
| `sheet`  | When its sheet opens.                                  |
| `panel`  | Each time the panel opens, and once as the app starts. |
| a number | Every that many seconds, while something wants it.     |
| `launch` | When the app starts.                                   |
| `wake`   | When the Mac wakes.                                    |

A read must be safe at each moment that its header lists, and only its author can promise this. A script has one read
at a time (M1). After a call that prints no state, Openspot reads the script once (M4). `OPENSPOT_REASON` gives the
reason: `panel`, `sheet`, `timer`, `launch`, `wake`, `search` or `change` (M6). Something wants a script while its sheet,
a widget or the menu bar shows it, or while the open panel reads it at `panel` (L3).

## The calls

| Call                                   | When                                                               |
| -------------------------------------- | ------------------------------------------------------------------ |
| `<script> read [text] [form]...`       | A moment, or a search change with `search=script` (02).            |
| `<script> run`                         | A click on a card area that is not a control, with no sheet or with `press=run`. |
| `<script> open <row id>`               | A row is picked (02).                                              |
| `<script> <id> [row id] [value]`       | A component changes or is pressed, with the id of its row (02).    |
| `<script> drop <path> [path]...`       | Files are dropped on its card, each path as its own argument (D3). |
| `<script> <command>`                   | A key that the person gave a command is pressed.                   |

`read` is the only reserved call. `run`, `open` and `drop` are default ids. A component cannot use a default id, and a
button can use only `open`. `call`, `reason` and `arg` are reserved ids too (05). A new default id reaches only a script that asks for it.

A drop on a card with a running call waits for that call (D4). A drop on a card with rows opens its sheet, and the answer to
the drop can select the row that it added with `select=` (02, D8). Presses of the keys of one script run one at a time, in
order, and never stop a call. Only the person gives a command its key (P8).

A script gets:

- **Arguments:** the id and its values. A value over 64 KB goes on stdin only (C6).
- **Stdin:** what the person filled in, as one block. A value that is not a field of the sheet comes as `value=`.
- **Environment:** `OPENSPOT_ID`, the ID of its spot, such as `home/coffee`. `OPENSPOT_DATA`, a folder for its files,
  shared by one plugin folder or by one `data` name. `OPENSPOT_SH`, the shell helper. `PATH`, with the `openspot` command
  first. `OPENSPOT_STAY=true` in a staying script (05).

```sh
#!/bin/sh
# title=Notes
# read=sheet
case "$1" in
  read) printf 'row=today\ntitle=Today\n' ;;
  open) open -a Notes ;;
esac
```

The shell helper gives `esc <text>`, which writes text as a value, and `value <id>`, which prints one value from stdin.
Loading it reads all of stdin. In a staying script it gives `next` and `arg <n>` for each call instead (05).

```sh
#!/bin/sh
. "$OPENSPOT_SH"
input=$(value input)
printf 'field=output\ntext=%s\n' "$(esc "$input")"
```

## Frames and the life of a call

A call can keep printing, and Openspot draws each frame at once. 02 says what each frame replaces.

- A `read` has 10 seconds until its first frame or its end. Any other call has no time limit.
- A new value for a component stops the older call of that component. A second press of a running call stops it: its process
  group gets the terminate signal, and then the kill signal. Quitting Openspot stops each call.
- A call ends when its output closes. A stopped call changes nothing.
- Exit 0 is success. Any other code is a failure, and the last line on stderr shows to the person. A failure can print
  `link=<url>`, the place that fixes it (R9).
- A stop can come at any time, and two calls can run at once, so a script never leaves a file half written.

A call shows its progress with a main `gauge` (02), such as `title=42%` and `value=0.42`. Openspot reads the codes `ESC ] 9;4;1;<percent>` as `value` and `ESC ] 9;<text>` as a toast, and removes each
other escape code (R12).

## The openspot command

A capability is `openspot <noun> <verb>`, and it works the same from a script and from a terminal (K1). `openspot help`
lists each one. A capability that cannot answer prints `status=<word>`. One that keeps state keeps it in its own
helper, which a script never starts or stops (K3). When macOS already has a command, such as `pbcopy` or `open`, use it.

A command that waits for the person, such as `openspot color pick` or `openspot folder pick`, fails in a read (K4). Run it
from a pick or an action.

`openspot guide` prints this guide. `openspot spot new <name> --from <kind>` writes a working spot to change, where a kind
is `button`, `list`, `number` or `form`. `openspot spot run <id> [call] [value]...` makes one call as Openspot makes it,
with the same environment, and prints each frame, then stderr, and exits with the code of the script. With no call, it
reads a spot that has a `read`, and runs one that has none. `openspot spot log <id>` prints the last calls that Openspot
made to a spot, each with its stdin, stdout, stderr and exit code.

`openspot render [--view <file.swift>] <file.png>` draws the sheet that stdin holds, with the plugin's view from a Swift file, and `openspot render --card <size> <file.png>` draws its card
at a size such as `wide`, so you can see a result before you stop. `openspot render --spot <id> [--card <size>] <file.png>`
draws the sheet or the card of an installed spot. Run `openspot check [--json] <plugins folder>` before you stop. It loads each plugin, reads each one that has a `read`, and prints
each fault, or with `--json` a list of `spot`, `file` and `fault`. `openspot spot show <id>` opens the panel with the spot
selected.

### Settings

```sh
# settings=folder
case "$1" in
  folder)
    picked=$(openspot folder pick)
    [ -n "$picked" ] && openspot setting set folder "$picked"
    ;;
esac
```

`settings` in the header names the values that the person chooses for the spot. The Settings spot lists each one, set or
not. Enter on it runs the action of the same name with no row, such as `folder`, and closes the panel when the action is
done. The action can answer with a form (02), and the person can remove a value with `⌘⌫`.

`openspot setting get <key>` prints a value that the person chose for the spot, or nothing when there is none.
`openspot setting set <key> [value]` keeps a value, and removes it when there is no value. A value lives in the person's
`config.toml`, under the spot that `OPENSPOT_ID` names, and `--spot <id>` names the spot from a terminal. Keep a choice of
the person there, such as a folder, and keep what the script makes, such as a cache, in `OPENSPOT_DATA` (K6). The Settings
spot also lists each value that the header does not name, so the person can remove it. `openspot folder pick` shows the folder window of macOS and
prints the folder that the person picks, or nothing after Cancel.

## Messages

A toast or a failure line says what happened, and why when you know it. It says what still worked, and how to fix the
rest with the exact step. Use plain words, a calm tone, and one or two short sentences, with each key in backticks.

| Instead of                    | Write                                                                                  |
| ----------------------------- | -------------------------------------------------------------------------------------- |
| `Oops! Something went wrong.` | `Openspot cannot find a screenshot.`                                                   |
| `Error 1: osascript failed.`  | ``Copied, but Openspot cannot paste. Press `⌘V`, or allow Openspot in Accessibility.`` |

## Decisions

| Decision                                                                      | Rejected                            |
| ----------------------------------------------------------------------------- | ----------------------------------- |
| The app's events are default ids, and `read` is the only reserved call.       | A verb for each kind of call.       |
| The first key names the kind of a block.                                      | A kind found from any key.          |
| Escape codes report and never act.                                            | OSC 8 as `link`.                    |
| A person can see and stop each call, so a call has no time limit.             | A `job` key.                        |
| A script runs once for each call, unless its header says `stay=true` (05).    | A process that stays by default.    |
| The header is in each file, and a scan runs nothing.                          | A manifest.                         |
| A plugin runs with the full access of the person.                    | A `uses` key, or a sandbox.         |
| A script keeps a setting through `openspot setting`, and asks for it when it needs it. | A `setting` header key with a kind, and required settings. |
| `press=run` lets a spot run at a press and keep its sheet for settings, behind ⌥. | A run button in its sheet, which costs a second press. |
