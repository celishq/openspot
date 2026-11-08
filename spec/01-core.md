# 01 Core

`final` `required`

```text
<script> read [text]          safe: show what you have
<script> <id> [value]...      act: something happened to this id
values on stdin               frames of key=value blocks on stdout
```

A plugin is one executable file, in any language, at the top of the plugins folder or one folder down (F1). One file gives
at most one spot (F4). Its ID is its path with no extension, such as `home/coffee` (F5).

## The format

A line is `key=value`, and it splits at its first `=`. A blank line ends a block. A line `---` ends a frame. In a value,
`\n` stands for a new line and `\\` for a backslash, and these are the only escapes. An empty value counts as no value.

```text
row=Safari
detail=App
run=/Applications/Safari.app

row=Notes
run=/Applications/Notes.app
```

The first key of a block names its kind. The kinds are in the registry of `README.md`. The first block with another first
key is the head, which says how the spot itself looks. A later block with another first key is skipped (R10). A line with
an unknown key is skipped (R2). Printing nothing means that there is nothing to show (R4).

`toast` and `open` can be keys of the head or blocks of their own, at any place (R11). `toast=Saved` shows at once, also
with the panel closed (R5). A key in backticks, such as ``toast=Press `⌘V` ``, shows as a key.

## The header

Comment lines right under the first line say what a script is, one `key=value` on each line. They start with `#`, `//` or
`--`, and the first other line ends them. Openspot reads the header without running the script, so a scan never runs a
script (F2). A header key that is not valid refuses that plugin, and the others still load (F6).

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
| `read` | The moments when Openspot reads the script. |
| `data` | The name of a data folder to share with other spots. |
| `drop` | The files that its card takes. See "Triggers". |
| `command` | A command that the person can give a key. See "Triggers". |

With `panel` in its `read`, the head of a frame can change `grid`, `size` and `order`, and a frame with no such key keeps
the header's value. The person's `config.toml` wins over both (F9).

## Moments

`read` is a list of moments, split by commas, such as `read=panel,60`. At each moment Openspot calls `<script> read`.

| Moment | Openspot reads it |
|---|---|
| none | Never. A click runs `<script>` with no argument. |
| `sheet` | When its sheet opens. |
| `panel` | Each time the panel opens, and once as the app starts. |
| a number | Every that many seconds, while something wants it. |
| `launch` | When the app starts, and at all times after. |
| `wake` | When the Mac wakes. |

A read must be safe at each moment that its header lists, and only its author can promise this (M5). A script has one read
at a time, and a new request joins the read that runs (M1). After a call that prints no state, Openspot reads the script
once (M4). A read gets the reason in `OPENSPOT_REASON`: `panel`, `sheet`, `timer`, `launch`, `wake`, `search` or `change`
(M6).

Something wants a script while its open sheet shows, while the open panel shows it in a widget or reads it at `panel`,
while the menu bar shows it, and at all times with `launch` in its `read` (L3).

## The calls

| Call | When |
|---|---|
| `<script>` | A click, with no `read` in its header. |
| `<script> read [text]` | A moment, or a search change with `search=script` (02). |
| `<script> run` | A click on a card with no sheet, with a `read` in its header. |
| `<script> open <run>` | A row is picked (02). |
| `<script> <action> [run]` | An action runs (02). |
| `<script> <part> [value]` | A part changes or is pressed (02). |
| `<script> on`, `off` | A toggle is pressed. |
| `<script> level <number>` | A slider moves. |
| `<script> drop <path> [path]...` | Files are dropped on its card. |
| `<script> <command>` | A key that the person gave a command is pressed. |

`read` is the only reserved word. `run`, `open`, `drop`, `on`, `off` and `level` are default ids: the app's own events. A
part cannot use a default id, and an action can use only `open`, to change what Enter does. `openspot check` reports a
clash (C1). A new default id reaches only a script whose header or output asks for it (C2).

A script gets:

- **Arguments:** the id and its values. A value over 64 KB is left out of the arguments, because the system limits them,
  and goes on stdin only (C6).
- **Stdin:** what the person filled in, as one block. A value of the sheet goes as it is, and any other value under the
  key `value`, such as `value=<run>`.
- **Environment:** `OPENSPOT_DATA` names a folder for its files. Scripts of one plugin folder share it, and `data=<name>`
  shares one with other spots. `OPENSPOT_SH` names the shell helper. `PATH` has the `openspot` command first (W1).

```sh
#!/bin/sh
# name=Notes
# read=sheet
case "$1" in
  read) printf 'row=Today\nrun=today\n' ;;
  open) open -a Notes ;;
esac
```

## The shell helper

A shell script can load `. "$OPENSPOT_SH"`, which gives two functions:

- `esc <text>` writes text as a value: a backslash as `\\` and a new line as `\n`. Use it for each value that comes from
  outside the script, such as a file name or a web page.
- `value <id>` prints the real text of one value from stdin, or nothing.

Loading reads all of stdin, so read stdin only through `value` after that. `$(...)` drops the new lines at the end of a
value: to keep them, write `text=$(value id; printf x)` and use `${text%x}`. In a staying script (05), `value` prints
nothing.

```sh
#!/bin/sh
. "$OPENSPOT_SH"
input=$(value input)
printf 'part=output\ntext=%s\n' "$(esc "$input")"
```

For many rows in one pipe, use `sed 's/\\/\\\\/g'`. With `jq -r`, use
`def esc: gsub("\\\\"; "\\\\") | gsub("\n"; "\\n");` and write `"row=\(.title | esc)"`.

## Frames and the life of a call

A call can keep printing. A line `---` ends a frame, and so does the end of the output. Openspot draws each frame at once
(S1). A frame with a layout replaces the sheet, and a frame with only parts changes those parts (S2).

- A `read` has 10 seconds until its first frame or its end, and it stops when nothing wants it (L1).
- Any other call has no time limit. It keeps running with the sheet and the panel closed (L2).
- A new value for a part stops the older call of that part, and only the newest answer shows (L4).
- A second press of a running part, action or card stops its call. Each process in its group gets the terminate signal,
  and Openspot kills what still runs 2 seconds later (L5).
- Quitting Openspot stops each call (L9). To outlive the app, start the work with `nohup` and exit.
- A call ends when its output closes (L10). A stopped call changes nothing (A3).
- Exit 0 is success. Any other code is a failure, and the last line on stderr shows to the person (R3). A failure can
  also print `open=<url>`, the place that fixes it, and the person's fix key opens it (R9).

A stop can come at any time, and two calls can run at once. So a script never leaves a file half written: it writes to a
temp name, then moves it (R8).

A call that does work reports its progress with the values that a metric prints (02), such as `title=42%`, `value=0.42`
and `detail=2 min left`. Only the last frame counts. Openspot reads the terminal codes `ESC ] 9;4;1;<percent>` as `value`
and `ESC ] 9;<text>` as a toast, in any output, and removes each other escape code. A code never makes the app act (R12).

## Triggers

`drop` makes the card take files. It holds extensions, such as `drop=mov,mkv`, `folder` for a folder or a bundle, or `*`
for each file and folder. A card takes a drag only when its `drop` takes each dragged file (D2).

```sh
#!/bin/sh
# name=To MP4
# symbol=film
# drop=mov,mkv,avi,webm
case "$1" in
  drop)
    shift
    for file; do
      ffmpeg -y -i "$file" "${file%.*}.mp4" >/dev/null 2>&1 || exit 1
    done
    printf 'toast=Done\n'
    ;;
esac
```

- A drop is one call, `drop <path> [path]...`, with each full path as its own argument (D3).
- A drop on a card with a running call waits for that call, and does not stop it (D4).
- A `drop` call runs as any other call does (D6).

`command` lists a command that the person can give a key, as `<id>:<title>[:<symbol>]`, one line for each command. Only
the person gives the key, and a script never holds one (P8). A press in any app runs `<script> <id>` with no panel. Presses
of the keys of one script run one at a time and in order, and a press never stops a call (C7).

```sh
#!/bin/sh
# name=Music
# command=pause:Play or pause
case "$1" in
  pause) osascript -e 'tell application "Music" to playpause' ;;
esac
```

## Decisions

| Decision | Rejected |
|---|---|
| The app's events are default ids, and `read` is the only reserved word. A model writes one `case` branch for each id. | A verb for each kind of call, such as `pick`, `set` and `do`. |
| The first key names the kind of a block, so a new kind is one new key. | A kind found from any key of a block. |
| Escape codes report and never act, because a script can print text from the web. | OSC 8 as `open`. |
| A failure links its fix, because the script knows the fix. | Reading the error text for a known fix. |
| Scripts in any language. Shell gives each Mac tool at once, and a start costs about 5 ms. | JS only. |
| A person can see and stop each call, so a call needs no time limit and no key. | A `job` key, or a lifetime value. |
| Each hook is a moment of `read`, and `stay=true` (05) covers the rest. | A `hook` call. |
| Streaming needs no key: a long call only prints more. | A stream mode. |
| The header is in each file, and a scan runs nothing. | A manifest. |
| A plugin runs with the full access of the person, so a header cannot grant or deny power (P1, P2). | A `uses` key, or a sandbox. |
| A script lists commands, and the person gives them keys. | A `global` key in the header. |
