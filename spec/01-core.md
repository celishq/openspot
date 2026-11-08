# 01 Core

`final` `required`

```text
<script> read [text]          safe: show what you have
<script> <id> [value]...      act: something happened to this id
values on stdin               frames of key=value blocks on stdout
```

A plugin is one executable file, in any language, at the top of the plugins folder or one folder down (F1). One file gives
at most one spot (F4), and its ID is its path with no extension, such as `home/coffee` (F5). A file that is not executable
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

The first key of a block names its kind, and the registry in `README.md` lists the kinds. The first block with another
first key is the head, which says how the spot itself looks. A later block with another first key is skipped (R10), and
so is a line with an unknown key (R2). Printing nothing means that there is nothing to show (R4).

`toast` and `open` can be keys of the head or blocks of their own (R11). `toast=Saved` shows at once, also with the panel
closed (R5).

## The header

Comment lines right under the first line say what a script is, one `key=value` on each line. They start with `#`, `//` or
`--`, and the first other line ends them. A scan reads them and never runs a script (F2). A header key that is not valid
refuses that plugin, and the others still load (F6).

```sh
#!/bin/sh
# name=Morning
# icon=sun.max
# shortcut=m
open -a Calendar
```

| Key                      | Meaning                                                                                                                                                              |
| ------------------------ | -------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `name`                   | The title. The default comes from the file name.                                                                                                                     |
| `icon`                   | Its picture, as in 02. A path that does not start with `/` starts at the folder of the script.                                                                       |
| `subtitle`               | The second line.                                                                                                                                                     |
| `shortcut`               | One letter. Hold the key that opens the panel, and press this letter to run it.                                                                                      |
| `size`                   | The size it prefers: `wide` (the default), `small`, `square`, `strip` or `large`. The grid can change it.                                                            |
| `read`                   | The moments when Openspot reads the script.                                                                                                                          |
| `data`                   | The name of a data folder to share with other spots.                                                                                                                 |
| `drop`                   | The files that its card takes: extensions such as `mov,mkv`, `folder`, or `*`.                                                                                       |
| `command`                | `<id>:<title>[:<symbol>]`, a command that the person can give a key. One line for each.                                                                              |

With `panel` in its `read`, the head of a frame can change `size`. The person's choice wins (F9). A script with `command`
lines has no card on the grid, because its commands are what it gives.

## Moments

`read` lists moments, split by commas, such as `read=panel,60`. At each moment Openspot calls `<script> read`.

| Moment   | Openspot reads it                                      |
| -------- | ------------------------------------------------------ |
| none     | Never. A click runs `<script>` with no argument.       |
| `sheet`  | When its sheet opens.                                  |
| `panel`  | Each time the panel opens, and once as the app starts. |
| a number | Every that many seconds, while something wants it.     |
| `launch` | When the app starts.                                   |
| `wake`   | When the Mac wakes.                                    |

A read must be safe at each moment that its header lists, and only its author can promise this (M5). A script has one read
at a time (M1). After a call that prints no state, Openspot reads the script once (M4). `OPENSPOT_REASON` gives the
reason: `panel`, `sheet`, `timer`, `launch`, `wake`, `search` or `change` (M6). Something wants a script while its sheet,
a widget or the menu bar shows it, or while the open panel reads it at `panel` (L3).

## The calls

| Call                                   | When                                                               |
| -------------------------------------- | ------------------------------------------------------------------ |
| `<script>`                             | A click, with no `read` in its header.                             |
| `<script> read [text] [form]...`       | A moment, or a search change with `search=script` (02).            |
| `<script> run`                         | A click on a card with no sheet, with a `read` in its header.      |
| `<script> open <row id>`               | A row is picked (02).                                              |
| `<script> <id> [row id] [value]`       | A component changes or is pressed, with the id of its row (02).    |
| `<script> drop <path> [path]...`       | Files are dropped on its card, each path as its own argument (D3). |
| `<script> <command>`                   | A key that the person gave a command is pressed.                   |

`read` is the only reserved word. `run`, `open` and `drop` are default ids. A component cannot use a default id, and a
button can use only `open` (C1). A new default id reaches only a script that asks for it (C2).

A drop on a card with a running call waits for that call (D4). Presses of the keys of one script run one at a time, in
order, and never stop a call (C7). Only the person gives a command its key (P8).

A script gets:

- **Arguments:** the id and its values. A value over 64 KB goes on stdin only (C6).
- **Stdin:** what the person filled in, as one block. A value that is not a field of the sheet comes as `value=`.
- **Environment:** `OPENSPOT_DATA`, a folder for its files, shared by one plugin folder or by one `data` name.
  `OPENSPOT_SH`, the shell helper. `PATH`, with the `openspot` command first (W1).

```sh
#!/bin/sh
# name=Notes
# read=sheet
case "$1" in
  read) printf 'row=today\ntitle=Today\n' ;;
  open) open -a Notes ;;
esac
```

The shell helper gives `esc <text>`, which writes text as a value, and `value <id>`, which prints one value from stdin.
Loading it reads all of stdin.

```sh
#!/bin/sh
. "$OPENSPOT_SH"
input=$(value input)
printf 'field=output\ntext=%s\n' "$(esc "$input")"
```

## Frames and the life of a call

A call can keep printing, and Openspot draws each frame at once (S1). A frame with a drawing replaces the sheet, and a frame
with only components changes those components (S2).

- A `read` has 10 seconds until its first frame or its end (L1). Any other call has no time limit (L2).
- A new value for a component stops the older call of that component (L4). A second press of a running call stops it: its process
  group gets the terminate signal, and then the kill signal (L5). Quitting Openspot stops each call (L9).
- A call ends when its output closes (L10). A stopped call changes nothing (A3).
- Exit 0 is success. Any other code is a failure, and the last line on stderr shows to the person (R3). A failure can print
  `open=<url>`, the place that fixes it (R9).
- A stop can come at any time, and two calls can run at once, so a script never leaves a file half written (R8).

A call reports progress with its `gauge` value in a frame (02): its `title`, its `detail` and its `value`, such as `title=42%` and
`value=0.42`. Openspot reads the codes `ESC ] 9;4;1;<percent>` as `value` and `ESC ] 9;<text>` as a toast, and removes each
other escape code (R12).

## The openspot command

A capability is `openspot <noun> <verb>`, and it works the same from a script and from a terminal (K1). `openspot help`
lists each one. A capability that cannot answer prints `status=<word>` (K4). One that keeps state keeps it in its own
helper, which a script never starts or stops (K3). When macOS already has a command, such as `pbcopy` or `open`, use it.

`openspot render <file.png>` draws the sheet that stdin holds, and `openspot render --card <size> <file.png>` draws its card
at a size such as `wide`, so you can see a result before you stop. Run `openspot check <plugins folder>` before you stop. It loads each plugin, reads each one that has a `read`, and prints
each fault.

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
| The app's events are default ids, and `read` is the only reserved word.       | A verb for each kind of call.       |
| The first key names the kind of a block.                                      | A kind found from any key.          |
| Escape codes report and never act.                                            | OSC 8 as `open`.                    |
| A person can see and stop each call, so a call has no time limit.             | A `job` key.                        |
| Each script runs once for each call. State lives in files or in a capability. | A process that stays between calls. |
| The header is in each file, and a scan runs nothing.                          | A manifest.                         |
| A plugin runs with the full access of the person (P1, P2).                    | A `uses` key, or a sandbox.         |
