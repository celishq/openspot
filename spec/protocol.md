# Openspot protocol

`1.0` `draft`

```text
spot   = header + frames                  the header is a frame in comments
frame  = head | block+                    a frame with a block is the whole picture, and a head alone is effects
block  = <kind>=<id> + key=value...
call   = <script> <id> [row] [value]...   with variables and stdin
event  ─ on= ─►  <script> read            each event that the header lists
block  ─ press ─►  <script> <id>          each block that the person presses or changes
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
too, with its header in `//` lines. It needs the Command Line Tools on the Mac that runs it. Its first run builds it once
in the background, and each later run starts the built program, until the file changes. A `.js` file runs inside the app
(see Modes).

The script says what it has and what it offers. Openspot and the person decide where, when and on which key it shows.

## The format

A line is `key=value`, and it splits at its first `=`. A blank line ends a block, and a line `---` ends a frame. In a
value, `\n` stands for a new line and `\\` for a backslash. These are the only escapes. An empty value counts as no value.
A value is never split again, so a URL or a colon stays whole in it. Only a list of plain words splits at commas, such as
`uses=screen,clipboard`. A thing with its own title or picture is a block of its own, such as an `option` after a
`choice`.

The first key of a block names its kind, and its value is the id of the block (U2). The one block whose first key names
no kind is the head, which holds the drawing and the effects of the frame. A line with an unknown key is skipped.

## The header

Comment lines right under the first line say what a script is. They start with `#`, `//` or `--`, and the first other
line ends them. They are a frame in comments: the keys of the spot, one `key=value` on each line, and after each blank
comment line a `button` or a `field` block, with the keys of the output. A scan reads them and never runs a script. A
header key that is not valid refuses that plugin, and the others still load.

```sh
#!/bin/sh
# title=Morning
# icon=sun.max
open -a Calendar
```

| Key       | Meaning                                                                                                                  |
| --------- | ------------------------------------------------------------------------------------------------------------------------ |
| `title`   | The title. The default comes from the file name.                                                                         |
| `icon`    | Its picture, as for a block. A path that does not start with `/` starts at the folder of the script.                     |
| `detail`  | The second line.                                                                                                         |
| `keyword` | One more word that finds it in the main search. A header can have more than one.                                         |
| `on`      | An event that reads it, with a filter of its value (B1, B6). A header can have more than one. See Events.               |
| `emits`   | The events that it raises with `openspot event emit`, split by commas (B7).                                              |
| `offers`  | `search`: its rows show in the main search (see Places).                                                                 |
| `drop`    | The files that its card takes: extensions such as `mov,mkv`, `folder`, or `*`.                                          |
| `size`    | The size it prefers: `wide` (the default), `small`, `square`, `strip` or `large`. The grid can change it, and the person's choice wins (F9). |
| `preview` | `sample` says that a read with `OPENSPOT_REASON=spot.preview` prints fake data. The store keeps that text as its preview. |
| `view`    | A SwiftUI file beside the script, such as `view=cups.swift` (see Views).                                                 |
| `mode`    | How it runs: `once` (the default), `stay` or `always` (I1).                                                              |
| `uses`    | What it uses, split by commas: `app`, `spots`, `screen`, `clipboard`, `calendar`, `network` and `files` (Z3).            |

| Block          | Meaning                                                                                                    |
| -------------- | ---------------------------------------------------------------------------------------------------------- |
| `button=<id>`  | A command that the person can give a key, with its `title` and its `icon`.                                 |
| `field=<key>`  | A value that the person chooses for the spot, with its `title`, which is its key by default, and its `icon`. |

```sh
#!/bin/sh
# title=Windows
# icon=macwindow
# uses=screen
#
# button=full
# title=Full screen
# icon=rectangle.inset.filled
#
# button=left
# title=Left side
# icon=rectangle.lefthalf.inset.filled
case "$1" in
  full) openspot window move "0 0 1 1" ;;
  left) openspot window move "0 0 1/2 1" ;;
esac
```

A script with `button` blocks in its header has no card on the grid, because its commands are what it gives.

## Events

An event is a word `<noun>.<verb>`, and it can carry a value. Each `on=` line names one event that reads the script, and
the rest of the line after a space is a regular expression that the event's value must match (B6). With no event, a click
runs `<script> open` and Openspot never reads it.

| Event                | Openspot raises it                                                        | Its value         |
| -------------------- | ------------------------------------------------------------------------- | ----------------- |
| `sheet.open`         | When its sheet opens.                                                     |                   |
| `panel.open`         | Each time the panel opens, and once as the app starts.                    |                   |
| `clock.<seconds>`    | Every that many seconds while something wants it, and when the Mac wakes. |                   |
| `search.text`        | At each change of the text of the main search (A1).                       | the typed text    |
| `sheet.text`         | At each change of the text of its own sheet's search.                     | the typed text    |
| `clipboard.change`   | When the clipboard changes.                                               |                   |
| `app.front`          | When another app comes to the front.                                      | its bundle ID     |
| `app.update`         | When the app has downloaded an update.                                    | its version       |
| `screen.wake`        | When the screen wakes.                                                    |                   |

```sh
#!/bin/sh
# title=Notes
# on=sheet.open
# on=app.front com\.apple\.Notes
```

Each read gets the event as `OPENSPOT_REASON` and its value as `OPENSPOT_VALUE` (B4). Openspot also reads a script with
`OPENSPOT_REASON=spot.change` after a call that printed no picture (M4), and with `spot.preview` for the store.

`openspot event emit <event> [value]` raises any event in the running app, from a script or from a terminal, and each spot
that lists it reads (B3). With the app closed, the command starts it first (S12). A spot that raises its own event names it
in `emits`, such as `emits=music.track`. `openspot check` reports each name in an `on` that Openspot does not raise and
that no spot in the folder names in its `emits`, and says how to fix it (B7). A read cannot raise the event that caused it,
which would read again without end, and `openspot check` warns of a spot whose `on` and `emits` share a name.

A `clock` and the events that are not `open` or `text` read a spot only while something wants it, and a spot with only
such events reads once when something starts to want it (B5). `app.update` reads each spot that lists it at once, wanted
or not. Something wants a script while its sheet, a widget or the menu bar shows it, or while the open panel reads it at
`panel.open` (L3). A read must be safe at each event that its header lists, and only its author can promise this. A
script has one read at a time (M1).

## Places

The person gives each spot its letter: hold the key that opens the panel, and press the letter to run the spot. The person
also picks the spots that show in the menu bar, the spots that float, and the order and the size of the cards. A script
cannot claim a letter or a place.

- `offers=search` shows the rows of the spot in the main search. It needs `on=panel.open` or a `clock`. Openspot ranks the
  rows by the person's picks.
- The person can give any spot a key or a shake of the pointer in Settings, which shows the spot in a small window of its
  own at the pointer: its sheet, or its card when it has no sheet (T1). The window stays while the person works in other
  apps, and the same key or shake closes it. The script never learns where it shows.

```js
// title=Calculator
// icon=equal.square
// on=search.text ^[0-9(]
// uses=clipboard
function main(args, env, input) {
  if (args[0] === "read") return openspot.call(["calc", "solve", env.OPENSPOT_VALUE]).stdout
  return ""
}
```

`on=search.text <pattern>` makes a spot answer the main search (A1). Its pattern searches the typed text, so `^` ties it
to the start. Openspot reads it at each change of a text that the pattern matches, such as `2*(3+4)`, with no pause, and a
newer text stops the older call (A2). Keep the answer fast. The rows show first in the main search, each with its
`detail`, until the newest text is answered, and they go at once when the pattern no longer matches (A3). A pick of a row
is `<script> open <row id>`. A spot whose only event is `search.text` has no card and shows only its answers.

An answer can be a card in place of its rows. When its head draws `grid.large=` or `grid.strip=` and its main block has a
`value`, Openspot shows one card at that size, `large` first, drawn as the spot's card is (U5), and a pick of it is
`<script> open <value>` (A4). An answer with neither shows its rows. A staying script answers each text as a call of its
own (I2). `openspot calc solve <words>...` prints the answer of a sum, a conversion or a date as a row, so a spot can
print it as it is.

A spot with a `clock` or another event, or with `mode=stay` or `always`, and a main `text`, `number` or `graph` can show in
the menu bar, when the person puts it there. Printing nothing removes the item until the next read. A spot with a `clock`
has no card on the grid until the person shows it (F7).

## Modes

`mode=once` starts a process for each call. `mode=stay` keeps one process that takes each call on stdin while something
wants it, and `mode=always` keeps it from the start of the app to its quit (I1). A staying spot can answer the main
search: each text is a call with its own id, and only the answer to the newest one shows (I2). A call has the same three
parts in each mode (C7).

A `.js` file runs inside the app, with its header in `//` lines (I3). The file defines `main(args, env, input)`, which
gets the three parts of each call as an array, an object and a string, and returns the text of a frame (I6).
`openspot.call(["calc", "solve", "2+2"])` asks the openspot command and returns `{ stdout, code }`, and a second argument
gives its stdin (I4). `openspot.frame(object)` writes an object as one block (C8). An inline spot has no files, no network
and no process of its own. It runs on a thread of its own, one call at a time, and a call that a newer one stopped before
it ran does not run. Openspot waits 2 ms for its frame in the turn of the key, and shows a later frame in the next turn,
with the last rows kept until then (I5). A call has 10 seconds. After that it stops and fails as a slow read fails, and
the spot answers its next call (I7).

```js
// title=Hello
// on=sheet.open
function main(args, env, input) {
  if (args[0] === "read") return openspot.frame({ row: "hi", title: `Hello from ${env.OPENSPOT_REASON}` })
  return ""
}
```

### A staying script

```sh
#!/bin/sh
# title=Relay
# mode=always
# on=panel.open
. "$OPENSPOT_SH"
main() {
  case "$1" in
    read) printf 'text=peer\ntitle=Waiting\n' ;;
    ping) printf 'toast=Pong\n' ;;
  esac
}
openspot_serve main "$@"
```

A script with `mode=stay` or `mode=always` is one process that talks both ways over stdio (Y1). Use it to keep a
connection, a model or a local server alive between calls. Each call reaches the running process, and no call starts a
second copy (Y2).

Openspot writes each call to stdin as one block, then a blank line (Y8). `call=<n>` numbers the call, an `arg` line gives
each argument in order, an `env.<name>` line gives each variable of the call, such as `env.OPENSPOT_REASON=panel.open`,
and one `input` line holds its stdin as one value, with each new line as `\n`. A value of the sheet lives inside `input`,
so no id that an author picks can clash with a key of the block. Stdin stays open while the script runs.

```text
call=4
arg=send
input=peer=127.0.0.1:47800\nmessage=Hello\n

```

`openspot_serve main "$@"` reads each block, runs `main` with its arguments, its variables and its stdin, as a script that
runs once gets them, and prints `call=<n>` before its output and `end=<n>` after it (Y9). So one `main` runs unchanged with
each mode. It runs one call at a time, and `exit` in `main` ends the script.

The script prints frames at any time, also with no call, such as when a message comes from another process. It ends each
call with `end=<n>` in the head of a frame (Y7), so a frame can end a call with a new picture, or with effects alone. A
frame of only `call=<n>` starts the output of that call: each frame after it, up to the one with `end=<n>`, answers the
call as a frame of a once script answers it, and a frame of only `end=<n>` ends the call with what it printed.

A call shows as running until its `end`, and a second press sends the block `stop=<n>`. A call that never ends runs until
the script ends, except a read after the first, which gets `stop=<n>` after 10 seconds and fails as a slow read. A newer
text sends `stop=<n>` for the read of the one before it, whose answer then changes nothing (I2). `openspot_serve` lets a
stopped call run to its end, and its frames change nothing.

With `mode=stay`, it runs while something wants it: its open sheet, a widget or the menu bar that shows it, the open panel
with `on=panel.open` or `on=search.text`, or a call that waits for its `end` (Y3). With `mode=always`, it runs from the
start of the app to its quit. When nothing wants it, Openspot closes its stdin. The script must end then, and so must each
process that it started. After 2 seconds its process group gets the terminate signal, and 2 seconds later the kill signal.
If it ends and something still wants it, the next event or call starts it again. After 3 failures in one minute, Openspot
tells the person, and starts it again only when a scan finds its file changed (Y5). Openspot can stop it at any time, so
what must survive goes in `OPENSPOT_DATA`.

## The calls

A call is `<script> <id> [row id] [value]...`: the id first, then the row it acts on, then its values.

| Call                                 | When                                                                   |
| ------------------------------------ | ---------------------------------------------------------------------- |
| `<script> read`                      | An event that its header lists.                                        |
| `<script> open [row id]`             | A row is picked, or a card with no sheet is pressed.                   |
| `<script> <id> [row id] [value]`     | A block changes or is pressed, with the id of its row.                 |
| `<script> drop <path> [path]...`     | Files are dropped on its card, each path as its own argument (D3).     |
| `<script> drag <row id> [row id]...` | Rows that hold files are dragged out of its sheet (O2).                |
| `<script> <command>`                 | A key that the person gave a command is pressed.                       |

`read` is the only reserved call. `open`, `drop` and `drag` are default ids, and a block cannot use one, but a button can
use `open`. A new default id reaches only a script that asks for it.

A drop on a card with a running call waits for that call (D4). A drop on a card with rows opens its sheet, and the answer
to the drop can select the row that it added with `select=` (D8). Presses of the keys of one script run one at a time, in
order, and never stop a call. Only the person gives a command its key (P8).

A call has three parts in each mode, as a CGI program gets them (C7):

- **Arguments:** the id, its row and its values, so that `case "$1"` handles each call. A value over 64 KB goes on stdin
  only (C6).
- **Variables:** `OPENSPOT_REASON` and `OPENSPOT_VALUE` of a read (B4), with `OPENSPOT_ID`, the ID of its spot, such as
  `home/coffee`, `OPENSPOT_DATA`, a folder for its files, shared by one plugin folder, `OPENSPOT_SH`, the shell helper,
  and `PATH`, with the `openspot` command first.
- **Stdin:** what the person filled in and typed, as one block: a line for each field of the sheet, `search=` with the
  text of the search, and a `form=` line for each other text that the person may have meant, such as the text typed in
  another keyboard layout or spelled in Latin letters. A value that is not a field of the sheet comes as `value=`.

`mode=once` gets them as its arguments, its environment and its stdin. `mode=stay` gets them in one block on stdin, and the
shell helper gives them to a function as a once script gets them (Y8, Y9). A `.js` file gets them as the arguments of
`main` (I6).

```sh
#!/bin/sh
# title=Notes
# on=sheet.open
. "$OPENSPOT_SH"
case "$1" in
  read) openspot_row today Today ;;
  open) open -a Notes ;;
esac
```

The shell helper gives `esc <text>`, which writes text as a value, and `value <id>`, which prints one value from stdin.
`openspot_kv <key> <value>` prints one line with its value written for you, `openspot_row <id> <title> [detail] [icon]`
prints one row, and `openspot_rows [kind]` prints a row, or a block of the kind given, for each line of stdin with its id,
title, detail and icon split by tabs (C8). `openspot_serve <function> "$@"` runs the function with the three parts of each
call: once in a script that runs once, and for each call in a staying script (Y9). Loading it reads all of stdin, except
in a staying script.

```sh
#!/bin/sh
. "$OPENSPOT_SH"
printf 'field=output\n'
openspot_kv value "$(value input)"
```

## Frames

A call can keep printing, and Openspot draws each frame at once. The script holds no state: each call gets the values on
stdin, and prints the whole output again, or nothing.

- A frame with a block is the whole picture. It replaces all that the spot shows.
- A frame of only a head changes no picture. Its effects act: `toast`, `link`, `select`, `progress` and `end`.
- A read that ends with no picture shows nothing. Another call that ends with no picture makes Openspot read the script
  once (M4).
- Openspot draws a change at once, and drops the answer to a call that a newer change has outdated (U10).
- A value from data goes through a helper: `openspot_kv`, `openspot_row` or `esc` in a shell, and `openspot.frame` in
  JavaScript. A helper writes each new line and backslash of a value, so that a value never adds a line or a block.
  `openspot check` warns of a block with a line that has no `=`, or with a key twice that only a list repeats, as a value
  with a new line prints (C8).

A call shows its progress with `progress=<0 to 1>` in a head, such as `progress=0.42`, and `title` and `detail` in that
head show on the spot only while the call runs. Openspot reads the codes `ESC ] 9;4;1;<percent>` as `progress` and
`ESC ] 9;<text>` as a toast, and removes each other escape code (R12).

## The life of a call

- A `read` has 10 seconds until its first frame or its end. In a staying script, a read after the first has 10 seconds
  until the frame that ends it: after that, the script gets `stop=<n>`, the call fails as a slow read, and its late answer
  changes nothing. A second slow call with no call in time between starts the script again. Any other call has no time
  limit.
- A new value for a block stops the older call of that block. A second press of a running call stops it: its process
  group gets the terminate signal, and then the kill signal. Quitting Openspot stops each call.
- A call ends when its output closes. A stopped call changes nothing.
- Exit 0 is success. Any other code is a failure, and the last line on stderr shows to the person. A failure can print
  `link=<url>`, the place that fixes it (R9). A failed read at `panel.open`, which the person did not ask for, only marks
  its card and goes to the app log at info (R13).
- A stop can come at any time, and two calls can run at once, so a script never leaves a file half written.

## Blocks

```text
grid=title title title title
grid=wifi  wifi  wifi  wifi
grid=nets  nets  nets  nets

text=title
title=Wi-Fi
detail=Home · 82 Mb/s

switch=wifi
title=Wi-Fi
value=true

repeat=nets

row=home
title=Home
icon=wifi
value=true

row=office
title=Office
icon=wifi

button=forget
title=Forget
shortcut=cmd+backspace
confirm=Press again to forget
```

A script prints blocks, and a drawing places them. The app owns each canvas, each size, each gap and each colour. A
script says only what goes where.

A block is `<kind>=<id>`. The id names the area that the block fills, the event that it sends, and the thing that moves
when it changes. Ids are unique in one output. Each kind keeps its data in `value`, and a graph repeats it.

| Kind      | Shows                                                   | Its own keys                                                    | Sends                  |
| --------- | ------------------------------------------------------- | --------------------------------------------------------------- | ---------------------- |
| `text`    | Words, and a small mark: a bar from `value`, or with `max` a bar for each `value` line. | `value`, `max`               |                        |
| `number`  | A big number, with its `title` under it. `display` shows in place of `value`. | `value`, `display`                     |                        |
| `graph`   | One `value` from 0 to 1 is a ring in a square area and a bar in a wide one. More are bars, and the last bar is the newest. | `value`, and `max` for bars |  |
| `picture` | A picture that fills its area.                          | `icon`                                                          |                        |
| `view`    | The SwiftUI view that the header names (see Views).     | any key that the view reads                                     |                        |
| `switch`  | A switch, or with `type=tick` a round tick before its words, for a thing to do. | `value`: `true` or `false`, `type`     | `<id> true` or `false` |
| `field`   | A text field, or with a `type` another input.           | `value`, `type`, `placeholder`, `required`, `readonly`, `min`, `max` | `<id> <value>`    |
| `choice`  | A menu of the `option` blocks after it, a list when it covers two lines or more, or swatches of `color` lines. | `color`, `value`, `type` | `<id> <option id>` |
| `option`  | One choice of the `choice` right before it, by its id.  | `title`, `icon`                                                 |                        |
| `button`  | A button, or an action (see below).                     | `shortcut`, `confirm`, `close`, `look`, `form`, `scope`         | `<id>`                 |
| `section` | A title over the lines that follow it.                  |                                                                 |                        |
| `repeat`  | The rows of the output (see Rows).                      | `grid` lines                                                    |                        |
| `row`     | One item of a list (see Rows).                          | the keys of Rows                                                | `open <id>`            |

The `type` of a field says which input it is: none for a line of text, `multiline` for a text of several lines, `slider`
for a slider from `min` to `max`, 0 to 100 by default, which sends when the person lets go, and `hotkey` for a key
combination that a press records. `type=multiple` lets a choice pick several (see Buttons and actions).

Each kind also takes `title`, `detail`, `tone` and `icon`. The value of `icon` says what the picture is: a path of a
picture file, such as `cups.png`, draws the picture; an `https://` URL draws a picture on the web, which Openspot fetches
the first time it draws it and keeps; any other path draws the file's Finder icon; a name of lowercase letters, digits and
dots, such as `wifi`, is an SF Symbol; and any other text, such as `😀`, is drawn as it is. `tone` is `good`, `warn` or
`bad`, a colour that means something. On a text, `good`, `warn` and `bad` colour its detail, or its title when it has no
detail, such as a `Late` in red. On a text or a number, `color=#RRGGBB` draws a thin bar of that colour at its leading
edge, such as the colour of a calendar. `look` is the box of a text, a number or a button: `tile`, `bare`, and on a button
also `chip` or `strong`. `align=left`, `right` or `center` places a block that is smaller than its cell, such as a `chip`
button. A key that a kind does not take is skipped.

## Drawings

A drawing places blocks. Each `grid=` line of the head is one line of the sheet, and each word is one cell. A word is the
id of a block, `.` is an empty cell, and `-` draws a divider across the line. The words of a line set the columns, so
there is no width to set. A block fills the rectangle of cells that its id covers, and each id covers a rectangle (U4). A
smaller block that lies in a larger one sits on top of it, at the edge it touches.

`grid.<size>=` lines draw the spot's card at a size: `small`, `wide`, `square`, `strip` or `large` (U5). A block that a
card drawing places and the sheet's drawing does not is drawn only on the card. A card's drawing can have more lines than
the card has rows: the app divides its room evenly. A place with no drawing takes the drawing of the nearest smaller size,
and a spot with none keeps its default card.

With no `grid=` line, the sheet takes its default drawing: one column of each block that is not a button, in the order
that they print, then its rows (U13). A `section` starts a new group. A drawing names a button only when the script draws
one, so a button with no drawing of its own is always an action.

## Buttons and actions

A `button` that a drawing places is drawn. A `button` that no drawing places is an action (U6): it shows in the ⌘K menu,
its `shortcut` works directly, and with no row selected it acts on the whole spot. An action on a row is
`<script> <id> <row id>`. `scope=command` keeps an action on the whole spot when a row is selected. `close=true` closes the
panel after it runs, and `confirm` asks for a second press, such as `Press again to delete`. `shortcut=escape` presses a
button, or runs an action, in place of closing the sheet, such as a Cancel. A ⌘K menu of more than 5 rows has a field that
searches them, so in it only a `shortcut` with `cmd` runs an action.

Enter on a row is the action `open`, which each spot has. A `button=open` gives it its word with `title`, and
`close=false` keeps the panel open after a pick. With `form=true`, Enter asks with a form first. A script prints it only
while it needs a value, such as an app that it has not been told to use.

A button with `form=true` asks for values first. The call runs once with empty stdin, and it prints a `title` in its head
and one `field`, `choice` or `switch` for each value. A choice starts on its first option. A form with one `choice` and
nothing else shows its options as rows under the search field, which narrows them, each with the picture of its `icon`,
and Enter or a click on one sends it. Esc clears the search first. With `type=multiple`, that choice picks several: a
checkmark marks each option of a `value` line, Enter sends the option of its row, and `⌘⇧A` sends each option with no
checkmark, one per line. The script keeps the picks and prints the form again with its new `value` lines, so the form
stays open, and the spot reads again. Then the same call runs with the values on stdin, and it can print the id of the row
to select. It can also print the form again, such as with a `title` that says what is wrong, and the form stays open.

## Rows

A `row` block is one item: `row=<id>` names it, and a pick sends `<script> open <id>`. Its `title` is the words it shows,
and with no `title` it shows its id. Rows always flow through a repeat, and with no `repeat` block they flow through a
list.

| Key        | Meaning                                                                                  |
| ---------- | ---------------------------------------------------------------------------------------- |
| `row`      | Required: the id.                                                                        |
| `title`    | The first line. Its id, when it has none.                                                |
| `detail`   | The second line.                                                                         |
| `icon`     | The picture.                                                                             |
| `parent`   | The place in its spot that it sits under. The main search shows `<spot> › <parent>`.     |
| `tone`     | A dot of its colour on the picture.                                                      |
| `value`    | `true` draws a checkmark at the end, for a thing that is on.                             |
| `hides`    | The id of an action that this row does not offer. Repeat the line for each one.          |
| `keyword`  | A word that finds the row in a search, which the row does not show.                      |
| `shortcut` | A key at the end of the row. A pick records a new key and calls `<id> <shortcut>`.        |
| `shake`    | `true` lets a shake of the pointer be the key that a pick records, as `<id> shake`.       |
| `file`     | The file that the row stands for (O1). See Files out.                                    |
| `to`       | The id of another spot that a pick goes to, as `<spot> open <row id>` with the row's fields on stdin (J1). |

Openspot searches the rows itself and sorts recent picks first. `on=sheet.text` sends each change of the search of its
sheet as a read, and the script prints the rows that match the text or any of its forms. A pick gets the text on stdin as
`search=<text>`, also when it comes before the read of that text. A read at any event gets the typed text too, so that its
answer gives the spot's new value with the rows of that text. `recents=false` in the head does not sort recent picks
first.

A `repeat` flows the rows through its area. Its own `grid=` lines are a drawing in which each word is the place of one
row, and the drawing repeats down for as long as there are rows (U7). Rows take the places in the order in which each word
first shows.

```text
repeat=photos          repeat=emoji                 repeat=apps
grid=a a b c           grid=a b c d e f g           grid=a
grid=a a d e
```

The first is a bento of one large place and four small ones, the second is a grid of seven to a line, and the third, the
default, is a list. A row draws its `icon`, its `title` and `detail`, its `tone`, its `value` and its `shortcut`. A row
that needs more offers it as an action, or the spot draws it with a `view`.

## The head

The head is the one block with no kind, at any place in the output, and it is not drawn. It holds:

- the picture: `grid=` lines for the sheet, `grid.<size>=` lines for the card, `main`, `title` and `detail` for its card,
  and `recents`;
- the effects: `toast`, `link=<url>`, which opens the URL, `progress`, `end=<call>`, which ends a call of a staying
  script, and `select=<row id>`, which reads again with that row selected when the call ends, such as the row that a drop
  added.

`toast=Saved` shows at once, also with the panel closed. A second block with no kind is skipped, and Openspot reports it.

## The main block

`main=<id>` in the head names the block that stands for the spot (H1). With no `main=`, the only `text`, `number`,
`graph`, `switch` or `field` with `type=slider` of the output stands for it, and with two or more, none does. The menu bar
and a widget show a main `text`, `number` or `graph`. A main `switch` shows on the card whether its thing is on, also when
the switch is in the sheet.

## The card

A spot with no `grid.<size>=` draws its default card: its picture, its title, its detail, and an arrow when it has a
sheet (U12). A spot whose output is one `switch` or one slider and nothing else draws that block as its card, with the
block's `title` and `detail`, and a press of the card changes it.

A press on a card area that is not a control opens the spot's sheet, or calls `<script> open` when it has none.

## Views

```text
#!/bin/sh
# title=Cups today
# on=panel.open
# view=cups.swift
printf 'view=cups\ntitle=3\nvalue=1\nvalue=0\nvalue=2\n'
```

```swift
import SwiftUI

struct SpotView: View {
    let spot: SpotInput

    var body: some View {
        VStack(alignment: .leading) {
            Text(spot["title"] ?? "–").font(.largeTitle.bold())
            Text("\(spot.all("value").count) days").foregroundStyle(.secondary)
        }
    }
}
```

`view=<file>` in the header names a SwiftUI view, and a `view=<id>` block draws it in the area of that id (V1). The
script and its view lie in a folder of their own, such as `cups/cups.sh` and `cups/cups.swift` (F10). The path starts at
the folder of the script, and the file ends in `.swift`. The file is not executable, so it is not a spot of its own.

The file declares `struct SpotView: View` with `let spot: SpotInput`, and it has no top-level code. Openspot gives
`SpotInput`:

| Member             | Gives                                                             |
| ------------------ | ----------------------------------------------------------------- |
| `spot["key"]`      | The last value of a key in the view's own block, or nil.          |
| `spot.all("key")`  | Each value of a key, in order, for a key that repeats.            |
| `spot.size`        | The size of its area, or of the whole card.                       |
| `spot.inset`       | The space that other cards keep between their edge and words.     |
| `spot.corner`      | The corner radius of the card.                                    |
| `spot.ink`         | The colour of words, which follows light and dark.                |
| `spot.secondary`   | The opacity of a second line, such as a detail.                   |
| `spot.accent`      | The accent colour.                                                |
| `spot.font`        | The fonts of the cards: `title`, `detail`, `metric` and `value`.  |

The view fills its area of a card drawing, such as `grid.large=cups cups chart chart`, or of a sheet drawing, and with no
card drawing it fills the whole card and is clipped to the card's shape (V3). In a sheet, its lines share the free height,
as a graph's do. Put `.padding(spot.inset)` on words so that they line up with other cards. The area's size comes from the
drawing, the card's `size` and the person, and the view cannot change it. The view gets the keys of its own block in each
frame that prints it (V4). A new frame draws the same view again, so its `@State` stays.

The view only draws. A press on the card works as on any card (V5).

Openspot compiles the view when its card first shows, never at a scan, and again when the file changes (V6). This needs
the Command Line Tools. A view that does not compile shows the first error in its card, and `openspot check` prints it. A
shared spot carries the compiled view beside its source as `<name>.view`, for both kinds of Mac, and Openspot uses it in
place of the source (V7).

The view runs inside Openspot. A crash in it quits Openspot, and a slow `body` slows the panel. Do the work in the
script, and keep `body` to drawing what the script printed.

## Metrics and widgets

A metric is a spot with a `clock`, and its main block is a `text`, a `number` or a `graph`. A widget or the menu bar can
show any script that reads, by its ID (H1).

```sh
#!/bin/sh
# title=Cups today
# icon=cup.and.saucer.fill
# on=clock.60
printf 'text=cups\ntitle=3\ndetail=Last at 14:20\n'
```

A TOML file in the plugins folder holds widgets, each of which shows several metrics on one card.

```toml
[[widgets]]
title = "System"
detail = "Battery, CPU, memory and devices"
grid = ["battery battery cpu cpu", "battery battery memory memory", "battery battery devices devices"]
opens = "system-info"
```

`grid` is a drawing of the names of metrics, as a card drawing is of ids, and its lines set the size of the widget, or
`size` sets it. `opens` names the spot that a press of the widget opens. A name is the file name of a script in the
widget's own folder first, and else the ID of a spot (F10).

## Files out

```sh
#!/bin/sh
# title=Shelf
# icon=tray.full
# drop=*
# on=sheet.open
. "$OPENSPOT_SH"
list="$OPENSPOT_DATA/files"
case "$1" in
  read)
    [ -f "$list" ] || exit 0
    while IFS= read -r path; do
      [ -e "$path" ] || continue
      openspot_row "$path" "${path##*/}" "" "$path"
      openspot_kv file "$path"
    done < "$list"
    ;;
  drop) shift; printf '%s\n' "$@" >> "$list" ;;
  drag)
    shift
    for path; do grep -vxF "$path" "$list" > "$list.new"; mv "$list.new" "$list"; done
    ;;
esac
```

A row with `file=<path>` stands for that file (O1). The person can drag the row out of the sheet into any app that takes
files, as they drag a file out of Finder. The path starts with `/`. A row whose file does not exist drags nothing.

The app that takes the drop chooses to copy or to move the file, as it does for a drag out of Finder. After a move, the
path is gone, so a read leaves out each file that does not exist.

When the drop ends in another app, Openspot calls `<script> drag <row id> [row id]...`, with the id of each row that the
drag held (O2). A drag that ends with no drop sends nothing. The script removes the rows, as a shelf does, or keeps them.
With no answer, Openspot reads again (M4). `drag` reaches only a script that prints `file`.

A drag of the picture in the head of the sheet drags every row that has a `file` at once, and `drag` gets the id of
each (O3).

## The openspot command

A capability is `openspot <noun> <verb>`, and it works the same from a script and from a terminal (K1). A call is one of two
kinds (S12):

- A call that reads or writes only files, or asks the Mac, such as `spot list`, `setting get`, `calc solve` or
  `screen shot`, gives the same answer with the app or without it. While the app runs, the command asks it over a socket,
  so a call starts no second app and finds its data ready (S1). With the app closed, the command does the work itself (S2).
- A call that needs the state of the running app, such as `app status`, `spot open`, `spot show`, `spot review`, `spot store`,
  `setting change`, `event emit` or `update check`, always goes to the app. With the app closed, the command
  starts it in the background and waits up to 10 seconds for it. After that it fails, and says to open Openspot.

Ctrl-C stops a call: the command closes its connection, and the app stops the work of that call, which then changes
nothing (S13). `spot run` and `check` stop each script that they started, and exit with 130. `openspot help` lists each
capability, and `openspot help <noun>` prints the guide of a noun, such as `screen` or `calendar`. A capability that
cannot answer prints `status=<word>`. One that keeps state keeps it in its own helper, which a script never starts or
stops (K3). When macOS already has a command, such as `open`, use it. For the screen and the clipboard, use
`openspot screen` and `openspot clipboard`, so that the person sees each use (Z5).

A noun names its commands, its events and its use together, such as `openspot clipboard copy`, `clipboard.change` and
`uses=clipboard`.

`openspot batch` reads one call per line from stdin, with its words split at spaces, and prints the output of each call
and then a line `---`. It stops at the first call that fails, with the stderr and the code of that call. It takes only a
call that the app answers, not one that draws or waits for the person, so a read can ask several things with one process
(K7). `--frame` makes `app status`, `spot list` and `setting list` print `key=value` blocks in place of JSON, each value
written as in a frame, so that a shell reads them with `while IFS== read -r key value` and needs no `jq` (K8).

A command that waits for the person, such as `openspot color pick` or `openspot folder pick`, fails in a read (K4). Run it
from a pick or an action.

`openspot guide` prints this guide. `openspot spot new <name> --from <kind>` writes a working spot to change, where a kind
is `button`, `list`, `number` or `form`. `openspot spot run <id> [call] [value]...` makes one call as Openspot makes it,
with the same three parts, and prints each frame, then stderr, and exits with the code of the script. With no call, it
reads a spot that has an event, and opens one that has none. `openspot spot log <id>` prints the last calls that Openspot
made to a spot, each with its stdin, stdout, stderr and exit code. A timed read or a search that does not fail leaves no
record. `openspot spot stats` prints what each spot cost and used, day by day (G1, Z10).

The spots of the app, such as Settings, Spots and New spot, are scripts in its `openspot` folder that use this command
like any other spot, and are always on. `openspot spot list [--core] [--frame]` prints the spots as JSON, `spot on|off <id>...`
turns spots that come with the app on or off, `spot open <id>` opens a spot's sheet, `spot store` opens Edit Spots with the
store of spots, and `spot review <id>` shows the text of a spot that comes with the app. `openspot key set` gives keys,
`menubar on|off <id>` places a spot in the menu bar, `setting list` prints each value that spots keep, `setting change <key>`
runs a value's action in the panel, `app status` prints the state of the app, `app login|link on|off` and `app quit` change
the app, `update check|install` updates it, and `prompt new <words>` prints a prompt for a coding agent. Each call that
changes the Mac, ends the app or opens the panel fails in a read. The config gives a spot a key of the panel, which opens
its sheet, by `key` in its `[[spots]]` table, and the default config gives `cmd+n` to New spot and `cmd+,` to Settings.

`openspot spot add <git url | folder | file.spot> [--yes]` puts a spot in the plugins folder, and `openspot spot remove <id>`
takes it out (N1). A git repository goes into a folder named after it, at its newest commit and with no `.git`. A folder is
copied, and each file of a `.spot` file is written at its path, where an equal file stays. A name that the plugins folder
has already is a fault. The first add of a spot prints the lines of its review, `Uses`, `Can also` and `Runs by itself`,
and changes nothing until it runs again with `--yes` when there is any. `spots.lock` in the config folder lists the
source, the commit, the paths, a hash of the files and the `uses` of each added spot, also of one that a review adds.
`openspot spot add` with no source adds each spot of `spots.lock` that is missing, a git one at its commit (N2), and
`spot add` of a source that `spots.lock` has already updates its spot, a git one to its newest commit (Z7). `spot remove`
moves to the Trash only a spot that `spot add` added, with all of its paths, and drops its line in `spots.lock`.

`openspot render [--view <file.swift>] <file.png>` draws the sheet that stdin holds, with the plugin's view from a Swift
file, and `openspot render --card <size> <file.png>` draws its card at a size such as `wide`, so you can see a result
before you stop. `openspot render --spot <id> [--card <size>] <file.png>` draws the sheet or the card of an installed spot.
Run `openspot check [--json] <plugins folder>` before you stop. It loads each plugin, reads each one that has an event, and
prints each fault, or with `--json` a list of `spot`, `file` and `fault`. `openspot spot show <id>` opens the panel with
the spot selected.

### Settings

```sh
# title=Repos
#
# field=folder
case "$1" in
  folder)
    picked=$(openspot folder pick)
    [ -n "$picked" ] && openspot setting set folder "$picked"
    ;;
esac
```

A `field` block in the header names a value that the person chooses for the spot. The Settings spot lists each one, set
or not. Enter on it runs the action of the same name with no row, such as `folder`, and closes the panel when the action is
done. The action can answer with a form, and the person can remove a value with `⌘⌫`.

`openspot setting get <key>` prints a value that the person chose for the spot, or nothing when there is none.
`openspot setting set <key> [value]` keeps a value, and removes it when there is no value. A value lives in the person's
`config.toml`, under the spot that `OPENSPOT_ID` names, and `--spot <id>` names the spot from a terminal. Keep a choice of
the person there, such as a folder, and keep what the script makes, such as a cache, in `OPENSPOT_DATA` (K6). The Settings
spot also lists each value that the header does not name, so the person can remove it. `openspot folder pick` shows the
folder window of macOS and prints the folder that the person picks, or nothing after Cancel.

## Trust

A spot runs with the person's rights, as any program that they start (Z1). Openspot asks nothing during daily use, and
blocks a call only in Careful mode. It shows what a spot can do at the moment of trust, which is an add or an update, and it
shows each use of a use after it happens, so that the person can undo it.

```sh
#!/bin/sh
# title=Coffee
# uses=app
openspot app quit
```

Openspot knows each call of `openspot` that a spot's process makes, also from a child that outlives it, and takes the
spot's ID and whether the call is in a read from its own record, not from the variables of the process (Z2). A call from
no spot is the person's call. Only the person's own processes reach the socket of the API (S14).

`uses` names what a spot uses (Z3). It is a closed set, and an unknown word is a fault that names the key.

| Use         | The calls that need it                                                                                 |
| ----------- | ------------------------------------------------------------------------------------------------------ |
| `app`       | `app login`, `app link`, `app quit`, `key set`, `menubar`, `update check` and `update install`         |
| `spots`     | `spot add`, `spot remove`, `spot on`, `spot off`, `spot new`, `spot run`, `spot log`, `setting list`, and `setting get`, `setting set` or `setting change` of another spot |
| `screen`    | `screen sources`, `screen shot`, `screen record`, `window frame`, `window move` and `color pick`       |
| `clipboard` | `clipboard copy`, `clipboard paste` and `clipboard read`                                               |
| `calendar`  | each call of `calendar` and `reminders`                                                                |
| `network`   | No call. It says that the spot reaches the network, which a review shows and Careful mode allows (Z8). |
| `files`     | No call. It says that the spot writes outside its data folder, which Careful mode allows (Z8).         |

Every other call, such as `calc solve`, `setting get` of its own spot or `spot stats`, needs no use.

A spot's call that needs a use that its header does not name still runs, unless Careful mode is on (Z4). Openspot then
shows one calm toast for each spot, use and day, such as ``Coffee quit Openspot without `uses=app` in its header. Add it to
stop this note.`` The person's own calls never show it. `openspot check` reports nothing for a missing use, because only a
run shows which calls a spot makes.

`openspot screen` and `openspot clipboard` count each use, and `screencapture`, `pbcopy` or `pbpaste` run directly do not
(Z5).

Before a person adds a spot, its review shows its title, the `uses` that it names, and a line `Can also` with what its text
seems to do and does not name (Z6): it reaches the network (`curl`, `wget`, `nc`), it deletes files (`rm`), it runs
`screencapture`, `pbcopy` or `pbpaste` directly, which `openspot screen` and `openspot clipboard` replace, or it calls
`openspot` for a use that `uses` does not name. The review reads the text and runs none of it. It warns and never refuses.

An update compares the `uses` of the new version, and the lines of its review under `Can also` and `Runs by itself`, with
those of the one in place (Z7). When none grew, it applies quietly. When a use grew, the review of a `.spot` file starts
with `This version adds: network`. `openspot spot add` prints that line, or `This version can do more.`, with each new
line, such as `Can also: Delete files with rm`, and changes nothing until it runs again with `--yes`.

Careful mode is a setting of the person, off by default, which Settings and `openspot app careful on|off` turn on and off,
and which `app status` shows as `careful` (Z8). No other spot can change it. It runs each process of a spot, and each
process that a `.js` spot starts with `openspot.call`, under `sandbox-exec`: no network unless `uses=network`, writes only
to its data folder, the temp folder, `/private/tmp`, `/dev` and the cache folder unless `uses=files`, also to the folder of
screenshots, the Desktop and Movies with `uses=screen`, no Apple Event, and reads everywhere. A capture that
`openspot screen` takes into a file that such a spot names follows the same folders, and another file fails, such as
``Careful mode keeps Recorder from writing /Users/a/Documents/talk.mp4. Name a file in its data folder or a temp folder, or
add `uses=files` to its header.`` A spot's call that needs a use that its header does not name fails, such as ``Careful
mode stopped Coffee, because it quit Openspot without `uses=app` in its header. Add it, or turn Careful mode off.`` A change
of the mode starts each staying process again. A `.js` spot has no files and no network in either mode. Without Careful
mode, the data folder alone is no boundary: a spot reads and writes each file that the person can (Z9).

### Stats

```text
openspot spot stats [--days N] [--spot id] [--frame|--json]
```

Openspot keeps what each spot cost and used, one file for each day, for 90 days (Z10). For each spot and day it counts the
runs, the failures, the CPU seconds, the bytes read from and written to the disk, the wakeups, and each call that needs a
use. `--days N` sums the last N days, today included, and 1 is the default. `--spot <id>` keeps one spot. The plain output
is for a person. `--frame` prints a `row=<id>` block for each spot, the most CPU time first, which a sheet can draw as it
is, then a `use=<n>` block for each call that needs a use, the newest first. `--json` prints the days as JSON. Today's
numbers are live in the running app, and the command reads the files when the app is closed (Z11).

| Row key              | Meaning                                                              |
| -------------------- | -------------------------------------------------------------------- |
| `title`, `detail`    | The name of the spot, and its numbers in words.                      |
| `runs`, `failures`   | The calls that ended, and those of them that failed.                 |
| `cpu`, `seconds`     | The CPU seconds of its processes, and the wall time of its calls.    |
| `read`, `written`    | The bytes that its processes read from and wrote to the disk.        |
| `wakeups`            | The times its processes woke the CPU.                                |
| `call.<noun>.<verb>` | The count of one call that needs a use, such as `call.screen.shot=2`. |
| `network`            | `declared` when its header names `network`.                          |
| `fault`, `tone`      | Its last fault, with `tone=bad`.                                     |

A `use` block holds `time`, `spot`, `call`, such as `app.quit`, and `declared`, `true` or `false`.

## Messages

A toast or a failure line says what happened, and why when you know it. It says what still worked, and how to fix the
rest with the exact step. Use plain words, a calm tone, and one or two short sentences, with each key in backticks.

| Instead of                    | Write                                                                                  |
| ----------------------------- | -------------------------------------------------------------------------------------- |
| `Oops! Something went wrong.` | `Openspot cannot find a screenshot.`                                                   |
| `Error 1: osascript failed.`  | ``Copied, but Openspot cannot paste. Press `⌘V`, or allow Openspot in Accessibility.`` |

## Decisions

| Decision                                                                                                    | Rejected                                     |
| ----------------------------------------------------------------------------------------------------------- | -------------------------------------------- |
| One `on` key lists events, and each moment of a read is an event `<noun>.<verb>` with a value (B6).          | `read` for places, `every` for seconds, `answers` for a pattern and `on` for events. |
| A filter on an event is a regular expression of its value, after a space.                                   | A key for each kind of filter.               |
| The reason of a read is the name of its event.                                                              | A word for each reason beside the events.    |
| A spot names the events that it raises in `emits`, so that a check can know each name (B7).                | Any word with a dot as an event.             |
| The app's events are default ids, and `read` is the only reserved call.                                     | A verb for each kind of call.                |
| A call is the id, its row and its values; what the person typed is on stdin.                                | The search text and its forms as arguments of `read`. |
| A press of a card with no sheet is `open` with no row.                                                      | A `run` id beside `open`.                    |
| The first key names the kind of a block.                                                                    | A kind found from any key.                   |
| The header is a frame in comments, and its blocks are kinds of the output: `button` and `field`.            | `command` and `setting` blocks of the header alone. |
| Each kind keeps its data in `value`.                                                                        | `point`, `on`, `level` and `text` by kind.   |
| An input is a `field` with a `type`, and a `graph` draws one value or many.                                 | `slider`, `hotkey` and `gauge` as kinds.     |
| A row and a card say that a thing is on only by `value`: a row's own, and the card's main `switch`.        | `on` in a row and in the head, and an `on` tone. |
| A frame with a block is the whole picture, and a head alone carries effects.                                | A later frame that merges what it prints.    |
| Escape codes report and never act.                                                                          | OSC 8 as `link`.                             |
| `openspot guide` is the one text of the contract, and a part takes only the keys that it names.             | A catalog of parts beside the guide.         |
| A value is whole, and a thing with its own title or picture is a block.                                     | `<id>:<title>:<icon>` in one value, which a URL or a time such as 09:30 breaks. |
| A person can see and stop each call, so a call has no time limit.                                           | A `job` key.                                 |
| A script runs once for each call, unless its header gives another `mode`, and a `.js` file runs inline (I1). | A process that stays by default, and `mode=inline`. |
| A call is the same arguments, variables and stdin in each mode, as CGI and the socket of the API give them (C7). | `call=` blocks read with `next`, and a JavaScript function for each id. |
| A helper writes each value from data (C8).                                                                  | An author who escapes each value by hand.    |
| The header is in each file, and a scan runs nothing.                                                        | A manifest.                                  |
| The header lists the events where a read is safe, because only the author knows what a read costs.         | `read=true`, with moments that the app picks. |
| A call that needs the app starts it, and a call of files runs where it is (S12).                           | A process of its own that answers in part, or fails. |
| One call of `openspot batch` asks several things, and `--frame` prints them as frames (K7, K8).              | A process and a `jq` for each thing.         |
| The person gives each letter, each float and each place in the menu bar, and the header only offers the main search. | `shortcut`, `tray`, `global` and `float` in the header, which two shared spots could both claim. |
| A pattern in the header says which text a spot answers, so a scan learns it with no run, and a key starts no other script. | Each script asked at each key. |
| An answer is a read at `search.text`, so a script has one shape for both.                                   | A new call, such as `answer <text>`.         |
| Answers show first, because they are about the whole text that the person typed.                            | A rank that each spot gives its rows.        |
| A plugin runs with the full access of the person, names what it uses in `uses`, and each use shows after it happens (Z1, Z4). | A prompt at each use, a refused call, or a sandbox by default. |
| A spot's call is known by Openspot's own record of its processes (Z2).                                      | `OPENSPOT_ID` alone, which a process can set or drop. |
| A missing use shows when a run makes it, and `openspot check` does not guess it (Z4).                      | A check that reads the text for calls.       |
| The person decides at an add or an update, which shows the uses and what grew (Z6, Z7).                     | A review of each call.                       |
| Careful mode is a sandbox that the person turns on, and it allows what `uses` names (Z8).                  | A data folder that claims to be a boundary.  |
| A script keeps a setting through `openspot setting`, and asks for it when it needs it.                      | A setting with a kind, and required settings. |
| The app owns each canvas, and a drawing only names areas, so each result stays even.                        | Sizes, gaps and colours in points.           |
| A drawing is CSS grid areas, which authors and models know.                                                 | Nested stacks, ratios and named layouts.     |
| A button that no drawing places is an action, so a verb is one kind in two places.                          | An `action` block beside a `button`.         |
| A row draws its own keys, and a richer row is an action or a view.                                          | A template with slots.                       |
| A form is the same call twice, so each call has one shape.                                                  | A `form` word.                               |
| One `main=` names what stands for a spot, so moving a block changes nothing.                                | The first `text`, `gauge` or `switch` of the output, and a `grid.tray` drawing. |
| One `icon` key, whose value says what the picture is.                                                       | `symbol`, `file`, `image` and `glyph`.       |
| A picture on the web is an `icon` URL, which Openspot fetches once and keeps.                               | A script that downloads each picture into `OPENSPOT_DATA`. |
| A look only draws a box, and a kind, a type or a drawing says the rest.                                     | `look=large`, `look=list`, `look=section` and `look=tick`. |
| A complex view is a `view` of the plugin in an area, so the text language stays small.                      | More words for each new look.                |
| One Swift file, compiled by Openspot, with no package and no build step.                                    | A Swift package, or a bundle that the author builds. |
| The script holds the state, and the view draws its own block, in Openspot's process.                        | A view that runs its own work or keeps its own data. |
| A widget of several metrics is a TOML file, which a person writes by hand.                                  | A `spot` block in a script's output.         |
| A widget's grid names its metrics, as a card drawing names its blocks.                                      | Letters, and a `places` table that names a metric for each. |
| The header holds the size that a spot prefers, and the person's choice wins.                                | A `size` in the head of a read.              |
| `file` names the file of a row, apart from its id and its picture.                                          | A row id that is a path, which makes the id say two things. |
| `drag` tells the script after the drop, and the script says what stays.                                     | A key that removes a row after a drag.       |
| Openspot drags the file itself, and the other app copies or moves it.                                       | A file promise that the script writes on request. |
| The script never learns where it shows.                                                                     | A call or an environment variable that names the window. |
| A staying script says so in its header, because a script that runs once reads stdin to its end before it answers. | A script that keeps running after its first answer stays. |
| A stop is a block of its own, `stop=<n>`, so no id that an author picks can clash with it.                  | A call named `stop`.                         |
| The script owns its sockets and its peers, and the app owns only stdio.                                     | A network capability in the app.             |

## Maintaining this protocol

This part is for the people who change Openspot. The build leaves it out of `openspot guide`.

### Goals

In order. An earlier goal wins when two goals conflict.

1. **A small plugin costs almost nothing.** One executable file. No build, no manifest, no account, no SDK.
2. **Openspot draws a plugin's data.** A script prints data, and Openspot draws it. A plugin can add its own SwiftUI
   view to its spot, and a script can open its own Mac window.
3. **Nothing runs by surprise.** Openspot runs a script only when a person acts or when its header says so.
4. **A plugin has real power.** It can use any Mac API, keep state in files, stream a long process and stay running.
5. **A coding agent writes a working plugin.** Given only `openspot guide` and one sentence, a coding agent writes a plugin
   that passes `openspot check --json` with `[]`, so that it shows on the grid, on its first try. `make eval-agent`
   measures it.

### Versions

The version at the top is the version of the contract. A new word raises its minor number, such as `1.1`. A draft becomes
`final` when a real use proves it, and a final version never changes the meaning of a word. A change that breaks an old
script raises the major number and adds a header key `protocol=<major>`, and a script with no such key is version 1.

### Rules of the text

1. **Only the contract.** What passes between a script and the host: the header, the arguments, stdin, stdout and the
   environment. Not how the host draws, its keys or its timings, unless a script must be written for a number.
2. **The example first.** One real example, then the rules.
3. **Each rule once,** in the prose. A rule keeps an ID, such as `C6`, only when code or a test names it, and an ID is
   never changed or used again.
4. **A decision** that later work must not break goes in the table of decisions, with the one it rejected.
5. **One way to do one thing,** and each word in one place, as the registry shows.

### How to extend

An old script never sees a word that it did not ask for, and an old app skips a word that it does not know.

| To add                | Add                                                         |
| --------------------- | ----------------------------------------------------------- |
| A thing that happens  | an event `<noun>.<verb>`                                    |
| A thing to draw       | a kind `<kind>=`, which an old app skips and reports        |
| A detail of a kind    | a key, or a `type` value                                    |
| A power of the Mac    | a noun: `openspot <noun> <verb>`, its events and its `uses` word, with its guide in `app/Help` |
| A complex look        | nothing: a `view` of the plugin                             |

### Registry

| Word                                                                                                     | Kind                 |
| -------------------------------------------------------------------------------------------------------- | -------------------- |
| `title`, `icon`, `detail`, `keyword`, `on`, `emits`, `offers`, `drop`, `size`, `preview`, `view`, `mode`, `uses` | Header key   |
| `button`, `field`                                                                                        | Header block         |
| `once`, `stay`, `always`                                                                                 | Mode                 |
| `app`, `spots`, `screen`, `clipboard`, `calendar`, `network`, `files`                                    | Use                  |
| `search`                                                                                                 | Offer                |
| `sheet.open`, `panel.open`, `clock.<seconds>`, `search.text`, `sheet.text`, `clipboard.change`, `app.front`, `app.update`, `screen.wake` | Event |
| `spot.change`, `spot.preview`                                                                            | Reason with no event |
| `read`                                                                                                   | Reserved call        |
| `open`, `drop`, `drag`                                                                                   | Default id           |
| `OPENSPOT_ID`, `OPENSPOT_REASON`, `OPENSPOT_VALUE`, `OPENSPOT_DATA`, `OPENSPOT_SH`                       | Environment variable |
| `search`, `form`, `value`                                                                                | Stdin key            |
| `openspot <noun> <verb>`, `openspot help <noun>`                                                         | Command              |
| `text`, `number`, `graph`, `picture`, `view`, `switch`, `field`, `choice`, `option`, `button`, `section`, `repeat`, `row` | Block kind |
| `multiline`, `slider`, `hotkey`, `multiple`, `tick`                                                      | Type                 |
| `title`, `detail`, `icon`, `tone`, `value`, `color`, `look`, `align`, `type`                             | Block key            |
| `parent`, `hides`, `keyword`, `shortcut`, `shake`, `file`, `to`                                          | Row key              |
| `grid`, `grid.<size>`, `main`, `title`, `detail`, `recents`, `toast`, `link`, `progress`, `select`, `end`, `call` | Head key    |
| `call`, `arg`, `env.<name>`, `input`, `stop`                                                             | Stdin key of a staying script |
| `title`, `detail`, `size`, `grid`, `opens`                                                               | Widget key           |

The verbs and the row keys of each `openspot` noun, such as `screen` or `calendar`, are in `openspot help <noun>`.

### Where the code differs

Each line goes when its phase lands.

| Part        | The code today                                                                                         |
| ----------- | ------------------------------------------------------------------------------------------------------ |
| Events      | Reads `read`, `every`, `answers`, the old event names and the head key `search=script`. Gives the reasons `panel`, `sheet`, `timer`, `search` and `change`, and `OPENSPOT_PREVIEW`. |
| Calls       | Gives the search text and its forms as arguments of `read`.                                            |
| Header      | Reads `command` and `setting` blocks, `offers=rows` and `offers=float`, and `mode=inline`.             |
| Blocks      | Reads `gauge`, `slider` and `hotkey` as kinds, and `look=tick`.                                        |
| Trust       | Reads the uses `update` and `settings`, and the guide names `OPENSPOT_TOKEN`.                          |

### Open

A stop of a call that `openspot_serve` runs does not end it early, so a slow staying call runs to its end.
