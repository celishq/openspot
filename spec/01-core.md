# 01 Core

`final` · Required for every plugin and every host.

```text
<script> read [text]          safe: show what you have
<script> <id> [value]...      act: something happened to this id
values on stdin               frames of key=value blocks on stdout
```

1. **Format:** a line is `key=value`. A blank line ends a block. A line `---` ends a frame. `\n` and `\\` are the only
   escapes. The header is the same format, in comment lines.
2. **Kind:** the first key of a block names its kind. The app skips a kind that it does not know.
3. **Calls:** `read` is safe, and the app runs it at the moments the header lists. Any other call acts, and runs only when
   the person acts. An id is one that the script printed or listed, or a default id of the app.
4. **Life:** an exit ends a call. A press stops it. Only `stay=true` (05) keeps a script running for more calls.

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
| `key` | One letter. Hold the key that opens the panel, and press this letter to run it. |
| `size` | `wide` (the default), `small`, `square`, `strip` or `large`. |
| `order` | Its place in the grid. A lower number comes first, and the default is 0. |
| `grid` | `false` to keep the spot off the grid. Search and its key still find it. |
| `read` | When Openspot reads the script. See below. |
| `data` | The name of a data folder to share with other spots. See "Rules for scripts" in 00. |

Other specs add keys: `rank` (02), `drop` and `command` (04), `stay` (05), and `tray` (06).

With `panel` in its `read`, the first block that a script prints can change `grid`, `size` and `order`. The person's choice in
Settings wins.

`read` is a list of moments, split by commas, such as `read=panel,60`. At each moment Openspot calls `<script> read`:

| Moment | Openspot reads it | Use it for |
|---|---|---|
| none | Never. A click runs `<script>` with no argument. | A script that does one thing. |
| `sheet` | When its sheet opens. | A list. |
| `panel` | Each time the panel opens, and once as the app starts. | A toggle, a slider, or a list for the main search. |
| a number | Every that many seconds, while something wants it, such as its open sheet. | A metric (06). |
| `launch` | When the app starts. | Work to do once, or a staying script that runs at all times. |
| `wake` | When the Mac wakes. | A value that is old after a sleep. |

A read must be safe at each moment that its header lists, so `read` does no work. A script has one read at a time. A
`panel` or a `sheet` moment uses an answer that is younger than 5 seconds. A number, `launch` and `wake` always run. After
a call that prints no state, Openspot reads the script again.

A read gets the reason in `OPENSPOT_REASON`: `panel`, `sheet`, `timer`, `launch`, `wake`, `search` or `change`. So a
script can do less on a timer than when its sheet opens.

## The calls

| Call | When | The script does |
|---|---|---|
| `<script>` | A click, with no `read` in its header | Does its work. |
| `<script> read [text]` | A moment, a sheet opens, or the search changes with `search=script` | Prints what to show. |
| `<script> run` | A click on a card with no sheet, with a `read` in its header | Does its work. |
| `<script> open <run>` | A row is picked (02) | Opens the row. |
| `<script> <action> [run]` | An action runs (02) | Does it. |
| `<script> <part> [value]` | A part changes, or a press of a part (03) | Prints the sheet, or nothing to be read again. |
| `<script> on`, `off` | A toggle is pressed | Turns it on or off. |
| `<script> level <number>` | A slider moves | Sets the level. |
| `<script> drop <path> [path]...` | Files are dropped on its card (04) | Does its work on each file. |
| `<script> <id>` | A key that a person gave a command is pressed (04) | Does its work. |

`read` is the only reserved word. `run`, `open`, `drop`, `on`, `off` and `level` are default ids: the app's own events.
A part cannot use a default id, and an action can use only `open`, to change what Enter does. `openspot check` reports a
clash.

A value over 64 KB is left out of the arguments, because the system limits them. Stdin still holds it: a value of the sheet
as it is, and any other value under the key `value`, such as `value=<run>`.

```sh
#!/bin/sh
# name=Notes
# read=sheet
case "$1" in
  read) printf 'row=Today\nrun=today\n' ;;
  open) open -a Notes ;;
esac
```

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
  script, such as a file name or a web page, write it with `esc` (see "The shell helper").
- For many rows in one pipe, use `sed 's/\\/\\\\/g'`. With `jq -r`, use `def esc: gsub("\\\\"; "\\\\") | gsub("\n"; "\\n");` and write `"row=\(.title | esc)"`.

The first key of a block names its kind: `row`, `action`, `field`, `part`, `section`, `toast` or `open`. So write that
key first. The first block with another first key says how the spot itself looks, and it can hold `search` and `recents`.
A later block with another first key is skipped, and `openspot check` reports it. Printing nothing means that there is
nothing to show.

To confirm what an action did, print `toast=Saved`, in the first block or as a block of its own at any place. Openspot shows
it, also with the panel closed. Put a key in backticks, such as ``toast=Press `⌘V` ``, and the toast shows it as a key.

## Toggles and sliders

Give the script `read=panel`, and let it print one block:

| Prints | Shows |
|---|---|
| `on=true` or `on=false` | A toggle. |
| `level=70`, and `min=0` and `max=100` | A slider. |

Both can print `title` and `detail`. The defaults come from the header.

## The shell helper

A shell script can load two functions. It is optional. Loading starts `cat` once. Up to 1 KB, each function starts no
program. Above that, it starts `sed`, `tr` or `awk`, and it finishes 1 MB in under 1 second.

```sh
#!/bin/sh
. "$OPENSPOT_SH"
input=$(value input)
printf 'part=output\ntext=%s\n' "$(esc "$input")"
```

- `esc <text>` writes text as a value: a backslash as `\\` and a new line as `\n`.
- `value <id>` prints the real text of one value from stdin. It prints nothing when stdin has no such value.
- Loading the file reads all of stdin once, so read stdin only through `value` after that.
- `$(...)` drops the new lines at the end of a value. To keep them, write `text=$(value id; printf x)` and use `${text%x}`.
- A script with `stay=true` keeps its stdin for its calls. There, `esc` works, and `value` prints nothing.

## How long a call runs

A call can keep printing, as `ffmpeg` does. A line `---` ends a frame, and the app draws it at once. A frame with a layout
replaces the sheet, and a frame with only parts changes those parts.

Two rules decide how long a call runs:

- A `read` has 10 seconds until its first frame or its end. It stops when nothing wants it, so a stream from a `read` stops
  when its sheet closes.
- Any other call has no time limit. It keeps running with the sheet and the panel closed, and Openspot keeps its last frame
  for the sheet. With no open sheet, a frame shows only its `toast`, its `on` and its `level`.

These stop a call:

- A new value for a part stops the older call of that part.
- A second press of a running part, action or card stops its call. Each process in its group gets the terminate signal.
  After 2 seconds, Openspot kills what still runs. A press within 1 second of the start of the call does nothing, so a
  double press does not stop it.
- Quitting Openspot stops each call. To outlive the app, start the work with `nohup` and then exit. A stop reaches the whole
  group, so `nohup` does not protect a child while its script still runs.

A stopped call changes nothing. A call ends when its output closes, so a script that leaves a child running sends the
output of that child somewhere else. A failed call always tells the person. A failed `read` from a number only dims the
last value.

A call that does work reports its progress with the values that a metric prints:

```text
title=42%
value=0.42
detail=2 min left

---
```

After the call has run for 1 second, its spot shows a ring from `value`, and a spinner with no `value`. Only the last frame
counts. The `title` and the `detail` show on the spot only while the call runs. The Openspot item in the menu bar shows the
oldest call and how many run, and a click on it opens the panel with that spot selected. The part or the action of the call
shows that it runs, and says that a press stops it.

A tool that already reports progress to a terminal needs no change. Openspot reads the progress code `ESC ] 9;4;1;<percent>`
as `value`, and the notification code `ESC ] 9;<text>` as a toast, each as a frame of its own. It removes each other escape
code, such as a colour, from the text.

## Rules

| ID | Rule |
|---|---|
| F1 | A plugin is one executable file, in any language, at the top of the plugins folder or one folder down. |
| F2 | Openspot learns what a plugin is from its header. A scan never runs a script. |
| F3 | Openspot scans the folder each time the panel opens, so a new plugin needs no restart. |
| F4 | One file gives at most one spot. It can offer many actions, which it prints. |
| F5 | The ID of a plugin is its path with no extension, such as `home/coffee`. |
| F6 | A header key that is not valid refuses that plugin. Openspot reports why and loads the others. |
| F9 | The header gives `grid`, `size` and `order`. With `panel` in its `read`, the head of a frame can change them, and a frame with no such key keeps the header's value. The person's `config.toml` wins over both. |
| C1 | `read` is the only reserved word. `run`, `open`, `drop`, `on`, `off` and `level` are default ids: the app's own events. A part cannot use a default id, and an action can use only `open`, to change it. `openspot check` reports a clash. |
| C2 | A new default id reaches only a script whose header or output asks for it. |
| C4 | Openspot waits for a pause before it sends a change of text or of a slider. |
| C5 | Text that the person types stays as typed until they press something. |
| C6 | A value too long for the arguments goes on stdin only. |
| M1 | A script has one read at a time. A new request joins the read that runs. |
| M2 | A `panel` or `sheet` moment takes an answer younger than 5 seconds. A change, a number, `launch` and `wake` always read. |
| M3 | Reads run at the same time. The panel never waits for one script. A spot shows its header until its answer arrives. |
| M4 | After a call that shows no state, Openspot reads the script once. |
| M5 | A read must be safe at each moment that its header lists. Only its author can promise this. |
| M6 | A read gets `OPENSPOT_REASON`: `panel`, `sheet`, `timer`, `launch`, `wake`, `search` or `change`. |
| W1 | Arguments hold the id and its values. Stdin holds what the person filled in, as one block. `OPENSPOT_DATA` names a folder for its files, and `data=<name>` shares one. `OPENSPOT_SH` names an optional shell helper with `esc` and `value`. `PATH` has the `openspot` command first. |
| R1 | What a script prints decides how its spot shows: rows, actions or parts make a list, `level` a slider, `on` a toggle. |
| R2 | A line with an unknown key is skipped. |
| R3 | Exit 0 is success. Any other code is a failure, and the last line on stderr shows to the person. |
| R4 | Printing nothing means that there is nothing to show. |
| R5 | `toast` shows at once, also with the panel closed. |
| R8 | A stop can come at any time, and two calls can run at once, so a script never leaves a file half written. |
| R9 | A failure can print `open=<url>`, the place that fixes it, and the person's fix key opens it. |
| R10 | The kinds are `row`, `action`, `field`, `part`, `section`, `toast`, `open` and `end`. The first block with another first key is the head. A later one is skipped, and `openspot check` reports it. |
| R11 | `toast` and `open` can be keys of the head, or blocks of their own at any place. |
| R12 | Openspot reads OSC 9;4 as the progress `value` and OSC 9 as a `toast`, in any output, and removes each other escape code. A code never makes the app act. |
| S1 | A line `---` ends a frame, and so does the end of the output. Openspot draws each frame at once. Any call can stream. |
| S2 | A frame with a layout replaces the sheet. A frame with only parts changes those parts. |
| S3 | A frame with no open sheet shows only its `toast` and its state. Openspot keeps the last frame for the sheet. |
| A3 | A stopped call changes nothing. Only a call that ended by itself can report that there is nothing to show. |
| L1 | A `read` has 10 seconds until its first frame or its end, and it stops when nothing wants it. |
| L2 | Any other call has no time limit. It keeps running with the sheet and the panel closed. |
| L3 | Something wants a script while its open sheet shows, while the open panel shows it in a widget or reads it at `panel`, while the menu bar shows it, or at all times with `launch` in its `read`. |
| L4 | A new value for a part stops the older call of that part, and only the newest answer shows. |
| L5 | A second press of a running part, action or card stops its call: terminate to its group, and kill 2 seconds later. |
| L6 | A call that runs 1 second shows on its part, its action, its spot and the menu bar item, so the person can find and stop it. A call to a staying script shows only by Y7. |
| L7 | When a sheet opens, Openspot reads, then adds the last frame of each running call. |
| L8 | The end of a call shows its `toast`. A failed call always tells the person. A failed timer read only dims the last value. |
| L9 | Quitting Openspot stops each call. |
| L10 | A call ends when its output closes. |
| L11 | A press within 1 second of the start of a call does nothing, so a double press does not stop it. |
| G1 | A running call shows a ring from the `value` of its last frame, or a spinner with no `value`. |
| G2 | The menu bar item shows the oldest running call and how many run. |
| G3 | A click on that item opens the panel with that spot selected. |
| G4 | A frame's `title` and `detail` show on the spot only while its call runs. |
| P1 | A plugin runs with the full access of the person. There is no sandbox. |
| P2 | So a header cannot grant or deny power, and there is no `uses` key. |
| P3 | Nothing runs on a scan (F2). |

## Why not

| Decision | Why | Rejected |
|---|---|---|
| The app's events are default ids, and `read` is the only reserved word | A model writes `case "$1" in` with one branch for each id. A default id is one more branch, with no verb to learn. | A verb for each kind of call, such as `pick`, `set` and `do`. |
| The first key names the kind | A model and a person see what a block is from its first line, and a new kind is one new key. | A kind found from any key of a block. |
| Escape codes report and never act | A script can print text from the web, and printed text must not open a link. | OSC 8 as `open`. |
| A failure links its fix, and one key opens it | The script knows the fix, so the app guesses nothing, and the key works with no mouse. | Reading the error text for a known fix. |
| Scripts, not a JS runtime | Shell gives each Mac tool at once, and a start costs about 5 ms. JS can come later as one more executable. | JS only. |
| Lifetime from rules | A person can see and stop work, so work needs no limit and no key. | A `job` key. A lifetime value. |
| Hooks are moments of `read` | Each need so far is a refresh at a moment, and `stay=true` covers the rest. | A `hook` call. |
| Streaming needs no key | A long call only prints more. | A stream mode. |
| Header in each file, no manifest | Goal 1, and a scan runs nothing. | A manifest. |
| No permission model | A script can already do all that the person can. A false limit is worse than none. | A `uses` key. |
