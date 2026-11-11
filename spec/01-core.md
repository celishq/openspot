# 01 Core

`draft` `required`

```text
<script> read [text]            safe: show what you have
<script> <id> [row] [value]     act: something happened to this id
values on stdin                 frames of key=value blocks on stdout
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

The script says what it has and what it offers. Openspot and the person decide where, when and on which key it shows.

## The format

A line is `key=value`, and it splits at its first `=`. A blank line ends a block, and a line `---` ends a frame. In a
value, `\n` stands for a new line and `\\` for a backslash. These are the only escapes. An empty value counts as no value.
A value is never split again, so a URL or a colon stays whole in it. Only a list of plain words splits at commas, such as
`read=panel,sheet`. A thing with its own title or picture is a block of its own, such as an `option` after a `choice`.

The first key of a block names its kind, and its value is the id of the block (U2). The one block whose first key names
no kind is the head, which holds the drawing and the effects of the frame. A line with an unknown key is skipped.

## The header

Comment lines right under the first line say what a script is. They start with `#`, `//` or `--`, and the first other
line ends them. They are a frame in comments: the keys of the spot, one `key=value` on each line, and after each blank
comment line a `command` or a `setting` block. A scan reads them and never runs a script. A header key that is not valid
refuses that plugin, and the others still load.

```sh
#!/bin/sh
# title=Morning
# icon=sun.max
open -a Calendar
```

| Key        | Meaning                                                                                                                  |
| ---------- | ------------------------------------------------------------------------------------------------------------------------ |
| `title`    | The title. The default comes from the file name.                                                                         |
| `icon`     | Its picture, as for a block. A path that does not start with `/` starts at the folder of the script.                     |
| `detail`   | The second line.                                                                                                         |
| `size`     | The size it prefers: `wide` (the default), `small`, `square`, `strip` or `large`. The grid can change it, and the person's choice wins (F9). |
| `read`     | The places where a read is safe: `sheet` and `panel`, split by commas (B6).                                              |
| `every`    | A number of seconds: a read that often while something wants it (B6).                                                   |
| `on`       | The events that read it, split by commas, such as `on=clipboard` (B1, B6).                                               |
| `emits`    | The events that it raises with `openspot event emit`, split by commas (B7).                                              |
| `drop`     | The files that its card takes: extensions such as `mov,mkv`, `folder`, or `*`.                                          |
| `offers`   | The places that it is made for, split by commas: `search`, `rows` or `float`.                                           |
| `answers`  | A regular expression of the texts of the main search that it answers, such as `^[0-9(]` (A1). See Places.               |
| `view`     | A SwiftUI file beside the script, such as `view=cups.swift` (03).                                                        |
| `mode`     | How it runs: `once` (the default), `stay`, `always` or `inline` (I1).                                                    |
| `uses`     | The powers that it uses, split by commas: `app`, `update`, `spots`, `settings`, `screen`, `clipboard`, `calendar`, `network` and `files` (Z3). |

| Block           | Meaning                                                                                              |
| --------------- | ---------------------------------------------------------------------------------------------------- |
| `command=<id>`  | A command that the person can give a key, with its `title` and its `icon`.                           |
| `setting=<key>` | A value that the person chooses for it, with its `title`, which is its key by default, and its `icon`. |

```sh
#!/bin/sh
# title=Windows
# icon=macwindow
# uses=screen
#
# command=full
# title=Full screen
# icon=rectangle.inset.filled
#
# command=left
# title=Left side
# icon=rectangle.lefthalf.inset.filled
case "$1" in
  full) openspot window move "0 0 1 1" ;;
  left) openspot window move "0 0 1/2 1" ;;
esac
```

A script with `command` blocks has no card on the grid, because its commands are what it gives.

## Places

The person gives each spot its letter: hold the key that opens the panel, and press the letter to run the spot. The person
also picks the spots that show in the menu bar, and the order and the size of the cards. A script cannot claim a letter or a
place.

`offers` names the places that a spot is made for:

- `search` shows the spot and its rows in the main search. It needs `panel` in its `read`, or an `every`. Openspot ranks the
  rows by the person's picks.
- `rows` shows its rows in the main search, but not the spot itself, and the spot has no card on the grid.
- `float` lets the person give the spot a key or a shake of the pointer, in Settings (T1). That key or shake shows the
  spot in a small window of its own at the pointer: its sheet, or its card when it has no sheet. The window stays while
  the person works in other apps, and the same key or shake closes it. The script never learns where it shows.

```sh
#!/bin/sh
# title=Calculator
# icon=equal.square
# answers=^[0-9(]
# uses=clipboard
case "$1" in
  read) [ -n "$2" ] && openspot calc solve "$2" ;;
  open) printf %s "$2" | openspot clipboard copy && printf 'toast=Copied %s\n' "$2" ;;
esac
```

`answers` makes a spot answer the main search (A1). Its value is a regular expression that searches the typed text, so
`^` ties it to the start. Openspot sends each text that it matches, such as `2*(3+4)`, as `<script> read <text> [form]...`
with `OPENSPOT_REASON=search`, at each change of the text with no pause, and a newer text stops the older call (A2). Keep
the answer fast. The rows show first in the main search, each with its `detail`, until the newest text is answered, and
they go at once when the pattern no longer matches (A3). A pick of a row is `<script> open <row id>`. A spot with
`answers` and no `read` has no card and shows only its answers. A staying script answers each text as a call of its own (I2). `openspot calc solve
<words>...` prints the answer of a sum, a conversion or a date as a row, so a spot can print it as it is.

A spot with an `every` or an `on`, or with `mode=stay` or `always`, and a main `text`, `number`, `gauge` or `graph` can show in the menu bar, when the
person puts it there. Printing nothing removes the item until the next read. A spot with an `every` has no card on the grid
until the person shows it (F7).

## When Openspot reads

Three keys say when Openspot calls `<script> read`, and each one holds one type of word, so that a wrong word is a fault
that names its key (B6).

| Key                | Openspot reads it                                                         |
| ------------------ | ------------------------------------------------------------------------- |
| none               | Never. A click runs `<script> open`.                                      |
| `read=sheet`       | When its sheet opens.                                                     |
| `read=panel`       | Each time the panel opens, and once as the app starts.                    |
| `every=<seconds>`  | Every that many seconds while something wants it, and when the Mac wakes. |
| `on=<event>,...`   | Each time one of the events occurs (B1).                                  |

An event is a word with a dot, or `clipboard`. Openspot raises `app.front` when another app comes to the front, with its
bundle ID as the value, `clipboard` when the clipboard changes, `screen.wake` when the screen wakes, and `app.update` when it
has downloaded an update, with its version as the value (B2). `openspot
event emit <event> [value]` raises any event in the running app, from a script or from a terminal, and each spot that
lists it in `on` reads (B3). With the app closed, the command starts it first (S12). `OPENSPOT_REASON` gives the event, and
`OPENSPOT_VALUE` its value (B4). A spot with an `on` reads only while something wants it, as for `every`, and a spot with an
`on` and no `read` or `every` reads once when something starts to want it (B5). `app.update` reads each spot that lists it
at once, wanted or not.

A spot that raises its own event names it in `emits`, such as `emits=music.track`. `openspot check` reports each name in an
`on` that Openspot does not raise and that no spot in the folder names in its `emits`, and says how to fix it (B7).

## Modes

`mode=once` starts a process for each call. `mode=stay` keeps one process that takes each call on stdin while something
wants it, and `mode=always` keeps it from the start of the app to its quit (05) (I1). A staying spot can answer the main
search: each text is a call with its own id, and only the answer to the newest one shows (I2). A call has the same three
parts in each mode (C7).

`mode=inline` runs a JavaScript file inside the app, such as `calc.js`, with its header in `//` lines (I3). The file
defines `main(args, env, input)`, which gets the three parts of each call as an array, an object and a string, and returns
the text of a frame (I6). `openspot.call(["calc", "solve", "2+2"])` asks the openspot command and returns `{ stdout, code }`,
and a second argument gives its stdin (I4). `openspot.frame(object)` writes an object as one block (C8). A `.js` file with no
`mode=inline` is no spot. An inline spot has no files, no network and no process of its own. It runs on a thread of its
own, one call at a time, and a call that a newer one stopped before it ran does not run. Openspot waits 2 ms for its frame
in the turn of the key, and shows a later frame in the next turn, with the last rows kept until then (I5). A call has 10
seconds. After that it stops and fails as a slow read fails, and the spot answers its next call (I7).

```js
// title=Hello
// mode=inline
// read=sheet
function main(args, env, input) {
  if (args[0] === "read") return openspot.frame({ row: "hi", title: `Hello from ${env.OPENSPOT_REASON}` })
  return ""
}
```

A read must be safe at each moment that its header lists, and only its author can promise this. A script has one read
at a time (M1). `OPENSPOT_REASON` gives the reason: `panel`, `sheet`, `timer`, `search` or `change` (M6). Something wants
a script while its sheet, a widget or the menu bar shows it, or while the open panel reads it at `panel` (L3).

## The calls

| Call                                   | When                                                                   |
| -------------------------------------- | ---------------------------------------------------------------------- |
| `<script> read [text] [form]...`       | A moment, a search change with `search=script`, or a text that `answers` matches. |
| `<script> open [row id]`               | A row is picked, or a card with no sheet is pressed.                   |
| `<script> <id> [row id] [value]`       | A block changes or is pressed, with the id of its row.                 |
| `<script> drop <path> [path]...`       | Files are dropped on its card, each path as its own argument (D3).     |
| `<script> drag <row id> [row id]...`   | Rows that hold files are dragged out of its sheet (O2).                |
| `<script> <command>`                   | A key that the person gave a command is pressed.                       |

`read` is the only reserved call. `open`, `drop` and `drag` are default ids, and a block cannot use one, but a button can
use `open`. A new default id reaches only a script that asks for it.

A drop on a card with a running call waits for that call (D4). A drop on a card with rows opens its sheet, and the answer
to the drop can select the row that it added with `select=` (D8). Presses of the keys of one script run one at a time, in
order, and never stop a call. Only the person gives a command its key (P8).

A call has three parts in each mode, as a CGI program gets them (C7):

- **Arguments:** the id and its values, so that `case "$1"` handles each call. A value over 64 KB goes on stdin only (C6).
- **Variables:** `OPENSPOT_REASON` and `OPENSPOT_VALUE` of a read (M6, B4), with `OPENSPOT_ID`, the ID of its spot, such as
  `home/coffee`, `OPENSPOT_DATA`, a folder for its files, shared by one plugin folder, `OPENSPOT_SH`, the shell helper,
  `OPENSPOT_TOKEN`, which marks its calls of `openspot` as the spot's (Z2), and `PATH`, with the `openspot` command first.
- **Stdin:** what the person filled in, as one block. A value that is not a field of the sheet comes as `value=`.

`mode=once` gets them as its arguments, its environment and its stdin. `mode=stay` gets them in one block on stdin, and the
shell helper gives them to a function as a once script gets them (Y8, Y9). `mode=inline` gets them as the arguments of
`main` (I6).

```sh
#!/bin/sh
# title=Notes
# read=sheet
. "$OPENSPOT_SH"
case "$1" in
  read) openspot_row today Today ;;
  open) open -a Notes ;;
esac
```

The shell helper gives `esc <text>`, which writes text as a value, and `value <id>`, which prints one value from stdin.
`openspot_kv <key> <value>` prints one line with its value written for you, `openspot_row <id> <title> [detail] [icon]`
prints one row, and `openspot_rows [kind]` prints a row, or a block of the kind given, for each line of stdin with its id,
title, detail and icon split by tabs (C8). `openspot_serve <function> "$@"` runs the function with the three parts of each call: once in a script
that runs once, and for each call in a staying script (Y9). Loading it reads all of stdin, except in a staying script.

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
- A frame of only a head changes no picture. Its effects act: `toast`, `link`, `select`, `progress` and `end` (05).
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

- A `read` has 10 seconds until its first frame or its end. Any other call has no time limit.
- A new value for a block stops the older call of that block. A second press of a running call stops it: its process
  group gets the terminate signal, and then the kill signal. Quitting Openspot stops each call.
- A call ends when its output closes. A stopped call changes nothing.
- Exit 0 is success. Any other code is a failure, and the last line on stderr shows to the person. A failure can print
  `link=<url>`, the place that fixes it (R9).
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
| `number`  | A big number, with its `title` under it.                | `value`                                                         |                        |
| `gauge`   | A ring in a square area, a bar in a wide one.           | `value` from 0 to 1                                             |                        |
| `graph`   | Bars. The last bar is the newest.                       | `value`, one line for each bar, and `max`                       |                        |
| `picture` | A picture that fills its area.                          | `icon`                                                          |                        |
| `view`    | The SwiftUI view that the header names (03).            | any key that the view reads                                     |                        |
| `switch`  | A switch.                                               | `value`: `true` or `false`                                      | `<id> true` or `false` |
| `slider`  | A slider. It sends when the person lets go.             | `value`, `min` and `max`, from 0 to 100 by default              | `<id> <number>`        |
| `field`   | A text field.                                           | `value`, `placeholder`, `type=multiline`, `required`, `readonly` | `<id> <text>`          |
| `choice`  | A menu of the `option` blocks after it, a list when it covers two lines or more, or swatches of `color` lines. | `color`, `value` | `<id> <option id>` |
| `option`  | One choice of the `choice` right before it, by its id. |  `title`, `icon`                                                |                        |
| `hotkey`  | A key combination that a press records.                 | `value`                                                         | `<id> <shortcut>`      |
| `button`  | A button, or an action (see below).                     | `shortcut`, `confirm`, `close`, `look`, `form`, `scope`         | `<id>`                 |
| `section` | A title over the lines that follow it.                  |                                                                 |                        |
| `repeat`  | The rows of the output (see Rows).                      | `grid` lines                                                    |                        |
| `row`     | One item of a list (see Rows).                          | the keys of Rows                                                | `open <id>`            |

Each kind also takes `title`, `detail`, `tone` and `icon`. The value of `icon` says what the picture is: a path
of a picture file, such as `cups.png`, draws the picture; an `https://` URL draws a picture on the web, which Openspot
fetches the first time it draws it and keeps; any other path draws the file's Finder icon; a name of lowercase letters,
digits and dots, such as `wifi`, is an SF Symbol; and any other text, such as `😀`, is drawn as it is. `tone` is
`good`, `warn` or `bad`, a colour that means something. On a
text, `good`, `warn` and `bad` colour its detail, or its title when it has no detail, such as a `Late` in red. On a text or
a number, `color=#RRGGBB` draws a thin bar of that colour at its leading edge, such as the colour of a calendar. `look` is
the box of a text, a number or a button: `tile`, `bare`, and on a button also `chip` or `strong`. On a switch, `look=tick`
draws a round tick before its words, for a thing to do. `align=left`, `right` or `center` places a block that is smaller
than its cell, such as a `chip` button. A key that a kind does not take is skipped.

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
and one `field`, `choice`, `switch` or `slider` for each value. A choice starts on its first option. A form with one
`choice` and nothing else shows its options as rows under the search field, which narrows them, each with the picture of
its `icon`, and Enter or a click on one sends it. Esc clears the search first. With `type=multiple`, that
choice picks several: a checkmark marks each option of a `value` line, Enter sends the option of its row, and `⌘⇧A` sends
each option with no checkmark, one per line. The script keeps the picks and prints the form again with its new `value`
lines, so the form stays open, and the spot reads again. Then the same call runs with the values on stdin, and it can
print the id of the row to select. It can also print the form again, such as with a `title` that says what is wrong, and
the form stays open.

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

Openspot searches the rows itself and sorts recent picks first. The head can change this on each read:

- `search=script` sends each search change as `<script> read <text> [form]...`, and the script prints the rows that match
  any of them. A form is another text that the person may have meant, such as the text typed in another keyboard layout
  or spelled in Latin letters. A pick gets the text on stdin as `search=<text>`, also when it comes before the read of
  that text. A read at a moment or after a change sends the typed text too, so that its answer gives the spot's new value
  with the rows of that text.
- `recents=false` does not sort recent picks first.

A `repeat` flows the rows through its area. Its own `grid=` lines are a drawing in which each word is the place of one
row, and the drawing repeats down for as long as there are rows (U7). Rows take the places in the order in which each word
first shows.

```text
repeat=photos          repeat=emoji                 repeat=apps
grid=a a b c           grid=a b c d e f g           grid=a
grid=a a d e
```

The first is a bento of one large place and four small ones, the second is a grid of seven to a line, and the third, the
default, is a list. A row draws its `icon`, its `title` and `detail`, its `tone`, its `value` and its `shortcut`. A row that needs more
offers it as an action, or the spot draws it with a `view` (03).

## The head

The head is the one block with no kind, at any place in the output, and it is not drawn. It holds four groups:

- the drawing: `grid=` lines for the sheet, and `grid.<size>=` lines for the card;
- the spot: `main`, and `title` and `detail` for its card;
- the rows: `search` and `recents`;
- the effects: `toast`, `link=<url>`, which opens the URL, `progress`, `end=<call>`, which ends a call of a staying
  script (05), and `select=<row id>`, which reads again with that row selected when the call ends, such as the row that a
  drop added.

`toast=Saved` shows at once, also with the panel closed. A second block with no kind is skipped, and Openspot reports it.

## The main block

`main=<id>` in the head names the block that stands for the spot (H1). With no `main=`, the only `text`, `number`,
`gauge`, `graph`, `switch` or `slider` of the output stands for it, and with two or more, none does. The menu bar and a
widget show a main `text`, `number`, `gauge` or `graph`. A main `switch` shows on the card whether its thing is on, also
when the switch is in the sheet.

## The card

A spot with no `grid.<size>=` draws its default card: its picture, its title, its detail, and an arrow when it has a
sheet (U12). A spot whose output is one `switch` or one `slider` and nothing else draws that block as its card, with the
block's `title` and `detail`, and a press of the card changes it.

A press on a card area that is not a control opens the spot's sheet, or calls `<script> open` when it has none.

## Metrics and widgets

A metric is a spot with an `every`, and its main block is a `text`, a `number`, a `gauge` or a `graph`. A
widget or the menu bar can show any script with a `read`, by its ID (H1).

```sh
#!/bin/sh
# title=Cups today
# icon=cup.and.saucer.fill
# every=60
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
`size` sets it. `opens` names the spot that a press of the widget opens. A name is the file name of a script in the widget's own folder first, and else the ID of a spot (F10).

## Files out

```sh
#!/bin/sh
# title=Shelf
# icon=tray.full
# drop=*
# read=sheet
# offers=float
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
- A call that needs the state of the running app, such as `app status`, `spot open`, `spot show`, `spot review`,
  `setting change`, `event emit` or `update check`, always goes to the app. With the app closed, the command
  starts it in the background and waits up to 10 seconds for it. After that it fails, and says to open Openspot.

Ctrl-C stops a call: the command closes its connection, and the app stops the work of that call, which then changes
nothing (S13). `openspot help` lists each capability, and `openspot help <noun>` prints the guide of a noun, such as
`screen` or `calendar`. A capability that cannot answer prints `status=<word>`. One that keeps state keeps it in its own
helper, which a script never starts or stops (K3). When macOS already has a command, such as `open`, use it. For the screen
and the clipboard, use `openspot screen` and `openspot clipboard`, so that the person sees each use (Z5).

`openspot batch` reads one call per line from stdin, with its words split at spaces, and prints the output of each call
and then a line `---`. It stops at the first call that fails, with the stderr and the code of that call. It takes only a
call that the app answers, not one that draws or waits for the person, so a read can ask several things with one process
(K7). `--frame` makes `app status`, `spot list`
and `setting list` print `key=value` blocks in place of JSON, each value written as in a frame, so that a shell reads them
with `while IFS== read -r key value` and needs no `jq` (K8).

A command that waits for the person, such as `openspot color pick` or `openspot folder pick`, fails in a read (K4). Run it
from a pick or an action.

`openspot guide` prints this guide. `openspot spot new <name> --from <kind>` writes a working spot to change, where a kind
is `button`, `list`, `number` or `form`. `openspot spot run <id> [call] [value]...` makes one call as Openspot makes it,
with the same three parts, and prints each frame, then stderr, and exits with the code of the script. With no call, it
reads a spot that has a `read`, and opens one that has none. `openspot spot log <id>` prints the last calls that Openspot
made to a spot, each with its stdin, stdout, stderr and exit code. A timed read or a search that does not fail
leaves no record. `openspot spot stats` prints what each spot cost and used, day by day (G1, Z10).

The spots of the app, such as Settings, Spots and New spot, are scripts in its `openspot` folder that use this command
like any other spot, and are always on. `openspot spot list [--core] [--frame]` prints the spots as JSON, `spot on|off <id>...`
turns spots that come with the app on or off, `spot open <id>` opens a spot's sheet, and `spot review <id>` shows the text
of a spot that comes with the app. `openspot key set` gives keys, `menubar on|off <id>` places a spot in the menu bar,
`setting list` prints each value that spots keep, `setting change <key>` runs a value's action in the panel, `app status`
prints the state of the app, `app login|link on|off` and `app quit` change the app, `update check|install` updates it, and
`prompt new <words>` prints a prompt for a coding agent. Each call that changes the Mac, ends the app or opens the panel
fails in a read. The config gives a spot a key of the panel, which opens its sheet, by `key` in its `[[spots]]` table, and
the default config gives `cmd+n` to New spot and `cmd+,` to Settings.

`openspot spot add <git url | folder | file.spot> [--yes]` puts a spot in the plugins folder, and `openspot spot remove <id>` takes
it out (N1). A git repository goes into a folder named after it, at its newest commit and with no `.git`. A folder is
copied, and a `.spot` file is written as a drop writes it. A name that the plugins folder has already is a fault.
`spots.lock` in the config folder lists the source, the commit, the paths, a hash of the files and the `uses` of each added
spot. `openspot spot add` with no source adds each spot of `spots.lock` that is missing, a git one at its commit (N2), and
`spot add` of a source that `spots.lock` has already updates its spot, a git one to its newest commit (Z7). `spot remove`
moves to the Trash only a spot that `spot add` added, with all of its paths, and drops its line in `spots.lock`.

`openspot render [--view <file.swift>] <file.png>` draws the sheet that stdin holds, with the plugin's view from a Swift
file, and `openspot render --card <size> <file.png>` draws its card at a size such as `wide`, so you can see a result
before you stop. `openspot render --spot <id> [--card <size>] <file.png>` draws the sheet or the card of an installed spot.
Run `openspot check [--json] <plugins folder>` before you stop. It loads each plugin, reads each one that has a `read`, and
prints each fault, or with `--json` a list of `spot`, `file` and `fault`. `openspot spot show <id>` opens the panel with
the spot selected.

### Settings

```sh
# title=Repos
#
# setting=folder
case "$1" in
  folder)
    picked=$(openspot folder pick)
    [ -n "$picked" ] && openspot setting set folder "$picked"
    ;;
esac
```

A `setting` block in the header names a value that the person chooses for the spot. The Settings spot lists each one, set
or not. Enter on it runs the action of the same name with no row, such as `folder`, and closes the panel when the action is
done. The action can answer with a form, and the person can remove a value with `⌘⌫`.

`openspot setting get <key>` prints a value that the person chose for the spot, or nothing when there is none.
`openspot setting set <key> [value]` keeps a value, and removes it when there is no value. A value lives in the person's
`config.toml`, under the spot that `OPENSPOT_ID` names, and `--spot <id>` names the spot from a terminal. Keep a choice of
the person there, such as a folder, and keep what the script makes, such as a cache, in `OPENSPOT_DATA` (K6). The Settings
spot also lists each value that the header does not name, so the person can remove it. `openspot folder pick` shows the
folder window of macOS and prints the folder that the person picks, or nothing after Cancel.

## Trust

A spot runs with the person's rights, as any program that they start (Z1). Openspot asks nothing during daily use and
blocks no call. It shows what a spot can do at the moment of trust, which is an add or an update, and it shows each use of
a power after it happens, so that the person can undo it.

```sh
#!/bin/sh
# title=Coffee
# uses=app
openspot app quit
```

Each process of a spot, and each inline spot, gets `OPENSPOT_TOKEN`: a random token for that process or that inline link,
which Openspot maps to the spot's ID while it runs (Z2). A call of `openspot` with that token is the spot's call, and the
children of a process inherit it. A call with no token, or with one that Openspot does not know, is the person's call. The
socket of the API is a file with mode `0600`, so only the person's own processes reach it.

`uses` names the powers that a spot uses (Z3). It is a closed set, and an unknown word is a fault that names the key.

| Use         | The calls that need it                                                                                 |
| ----------- | ------------------------------------------------------------------------------------------------------ |
| `app`       | `app login`, `app link`, `app quit`, `key set` and `menubar`                                           |
| `update`    | `update check` and `update install`                                                                    |
| `spots`     | `spot add`, `spot remove`, `spot on`, `spot off`, `spot new`, `spot run` and `spot log`                |
| `settings`  | `setting list`, and `setting get`, `setting set` or `setting change` of another spot                   |
| `screen`    | `screen sources`, `screen shot`, `screen record`, `window frame`, `window move` and `color pick`       |
| `clipboard` | `clipboard copy`, `clipboard paste` and `clipboard read`                                              |
| `calendar`  | each call of `calendar` and `reminders`                                                                |
| `network`   | No call. It says that the spot reaches the network, which a review shows and Careful mode allows (Z8). |
| `files`     | No call. It says that the spot writes outside its data folder, which Careful mode allows (Z8).         |

Every other call, such as `calc solve`, `setting get` of its own spot or `spot stats`, needs no use.

A spot's call that needs a use that its header does not name still runs (Z4). Openspot then shows one calm toast for each
spot, use and day, such as ``Coffee quit Openspot without `uses=app` in its header. Add it to stop this note.`` The person's
own calls never show it. `openspot check` reports nothing for a missing use, because only a run shows which calls a spot
makes.

`openspot screen` and `openspot clipboard` count each use, and `screencapture` or `pbcopy` run directly do not (Z5).

Before a person adds a spot, its review shows its title, the `uses` that it names, and a line `Can also` with what its text
seems to do and does not name (Z6): it reaches the network (`curl`, `wget`, `nc`), it deletes files (`rm`), it runs
`screencapture` or `pbcopy` directly, which `openspot screen` and `openspot clipboard` replace, or it calls `openspot` for a
use that `uses` does not name. The review reads the text and runs none of it. It warns and never refuses.

An update compares the `uses` of the new version with those of the one in place (Z7). When none grew, it applies quietly.
When one grew, the review of a `.spot` file starts with `This version adds: network`, and `openspot spot add` prints that
line and changes nothing until it runs again with `--yes`.

Careful mode is a setting of the person, off by default, which Settings and `openspot app careful on|off` turn on and off,
and which `app status` shows as `careful` (Z8). It runs each process of a spot under `sandbox-exec`: no
network unless `uses=network`, writes only to its data folder, the temp folder and the cache folder unless `uses=files`,
also to the folder of screenshots, the Desktop and Movies with `uses=screen`, and reads everywhere. A process that stays keeps the
mode that it started in until it starts again. An inline spot has no files and no network in either mode. Without Careful mode, the data folder alone is no
boundary: a spot reads and writes each file that the person can (Z9).

### Stats

```text
openspot spot stats [--days N] [--spot id] [--frame|--json]
```

Openspot keeps what each spot cost and used, one file for each day, for 90 days (Z10). For each spot and day it counts the
runs, the failures, the CPU seconds, the bytes read from and written to the disk, the wakeups, and each use, such as
`screen.shot` or `clipboard.copy`. It keeps the last fault of each spot, and a short log of the uses of a power: the time,
the spot, the call and whether its header names the use. It does not count the network: a spot's `network` shows as
declared.

`--days N` sums the last N days, today included, and 1 is the default. `--spot <id>` keeps one spot. The plain output is
for a person. `--frame` prints a `row=<id>` block for each spot, the most CPU time first, which a sheet can draw as it is,
then a `power=<n>` block for each use of a power, the newest first. `--json` prints the days as JSON. Today's numbers are
live in the running app, and the command reads the files when the app is closed (Z11).

| Row key              | Meaning                                                              |
| -------------------- | -------------------------------------------------------------------- |
| `title`, `detail`    | The name of the spot, and its numbers in words.                      |
| `runs`, `failures`   | The calls that ended, and those of them that failed.                 |
| `cpu`, `seconds`     | The CPU seconds of its processes, and the wall time of its calls.    |
| `read`, `written`    | The bytes that its processes read from and wrote to the disk.        |
| `wakeups`            | The times its processes woke the CPU.                                |
| `use.<name>`         | The count of one use, such as `use.screen.shot=2`.                   |
| `network`            | `declared` when its header names `network`.                          |
| `fault`, `tone`      | Its last fault, with `tone=bad`.                                     |

A `power` block holds `time`, `spot`, `call`, such as `app.quit`, and `declared`, `true` or `false`.

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
| The app's events are default ids, and `read` is the only reserved call.                                     | A verb for each kind of call.                |
| A press of a card with no sheet is `open` with no row.                                                      | A `run` id beside `open`.                    |
| The first key names the kind of a block.                                                                    | A kind found from any key.                   |
| Each kind keeps its data in `value`.                                                                        | `point`, `on`, `level` and `text` by kind.   |
| A row and a card say that a thing is on only by `value`: a row's own, and the card's main `switch`.        | `on` in a row and in the head, and an `on` tone. |
| A frame with a block is the whole picture, and a head alone carries effects.                                | A later frame that merges what it prints.    |
| Escape codes report and never act.                                                                          | OSC 8 as `link`.                             |
| `openspot guide` is the one text of the contract, and a part takes only the keys that it names.             | A catalog of parts beside the guide.         |
| A value is whole, and a thing with its own title or picture is a block.                                     | `<id>:<title>:<icon>` in one value, which a URL or a time such as 09:30 breaks. |
| The header is a frame in comments, so a command or a setting is a block, as in the output.                  | A `command` line and a `settings` list of colon fields.                     |
| A person can see and stop each call, so a call has no time limit.                                           | A `job` key.                                 |
| A script runs once for each call, unless its header gives another `mode` (I1).                                       | A process that stays by default.             |
| A call is the same arguments, variables and stdin in each mode, as CGI and the socket of the API give them (C7).    | `call=` blocks read with `next`, and a JavaScript function for each id. |
| A helper writes each value from data (C8).                                                                  | An author who escapes each value by hand.    |
| The header is in each file, and a scan runs nothing.                                                        | A manifest.                                  |
| `read` lists the places where a read is safe, because only the author knows what a read costs.             | `read=true`, with moments that the app picks. |
| Each key of the reads holds one type: places in `read`, seconds in `every` and events in `on` (B6).          | One `read` list of places, numbers and events, where a typo is an event. |
| A spot names the events that it raises in `emits`, so that a check can know each name (B7).                | Any word with a dot as an event.             |
| A call that needs the app starts it, and a call of files runs where it is (S12).                           | A process of its own that answers in part, or fails. |
| One call of `openspot batch` asks several things, and `--frame` prints them as frames (K7, K8).              | A process and a `jq` for each thing.         |
| The person gives each letter and puts each spot in the menu bar, and the header only offers places.         | `shortcut`, `tray` and `global` in the header, which two shared spots could both claim. |
| One `offers` key lists the places a spot is made for.                                                       | A key for each place.                        |
| A pattern in the header says which text a spot answers, so a scan learns it with no run, and a key starts no other script. | Each script asked at each key. |
| An answer is the call of a search that the script does, so a script has one shape for both.                 | A new call, such as `answer <text>`.         |
| Answers show first, because they are about the whole text that the person typed.                            | A rank that each spot gives its rows.        |
| A plugin runs with the full access of the person, names its powers in `uses`, and each use shows after it happens (Z1, Z4). | A prompt at each use, a refused call, or a sandbox by default. |
| A spot's call is known by a token that Openspot gives its process (Z2).                                     | `OPENSPOT_ID`, which any process can set.    |
| A missing use shows when a run makes it, and `openspot check` does not guess it (Z4).                      | A check that reads the text for calls.       |
| The person decides at an add or an update, which shows the uses and what grew (Z6, Z7).                     | A review of each call.                       |
| Careful mode is a sandbox that the person turns on, and it allows what `uses` names (Z8).                  | A data folder that claims to be a boundary.  |
| A script keeps a setting through `openspot setting`, and asks for it when it needs it.                      | A `setting` header key with a kind, and required settings. |
| A component is `<kind>=<id>`, so a block says what it is and where it goes in one line.                     | `part=<id>` with a kind found from its keys. |
| The app owns each canvas, and a drawing only names areas, so each result stays even.                        | Sizes, gaps and colours in points.           |
| A drawing is CSS grid areas, which authors and models know.                                                 | Nested stacks, ratios and named layouts.     |
| A button that no drawing places is an action, so a verb is one kind in two places.                          | An `action` block beside a `button`.         |
| A row draws its own keys, and a richer row is an action or a view.                                          | A template with slots.                       |
| A form is the same call twice, so each call has one shape.                                                  | A `form` word.                               |
| One `main=` names what stands for a spot, so moving a block changes nothing.                                | The first `text`, `gauge` or `switch` of the output, and a `grid.tray` drawing. |
| One `icon` key, whose value says what the picture is.                                                       | `symbol`, `file`, `image` and `glyph`.       |
| A picture on the web is an `icon` URL, which Openspot fetches once and keeps.                               | A script that downloads each picture into `OPENSPOT_DATA`. |
| A look only draws a box, and a kind or a drawing says the rest.                                             | `look=large`, `look=list` and `look=section`. |
| A complex view is a `view` of the plugin in an area, so the text language stays small.                      | More words for each new look.                |
| A widget of several metrics is a TOML file, which a person writes by hand.                                  | A `spot` block in a script's output.         |
| A widget's grid names its metrics, as a card drawing names its blocks.                                      | Letters, and a `places` table that names a metric for each. |
| The header holds the size that a spot prefers, and the person's choice wins.                                | A `size` in the head of a read.              |
| `file` names the file of a row, apart from its id and its picture.                                          | A row id that is a path, which makes the id say two things. |
| `drag` tells the script after the drop, and the script says what stays.                                     | A key that removes a row after a drag.       |
| Openspot drags the file itself, and the other app copies or moves it.                                       | A file promise that the script writes on request. |
| The header offers a float, and the person gives it a key or a shake in Settings.                            | A key or a shake in the header, which a shared script could claim. |
| The script never learns where it shows.                                                                     | A call or an environment variable that names the window. |
