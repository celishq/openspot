# Openspot protocol

`1.0` `draft`

Openspot runs small programs called spots. A spot prints what to show, and Openspot draws it and calls the spot again when
something happens. This page is all you need to write one: start with a first spot, then read on as you need more.

MUST, MUST NOT, SHOULD and MAY have the meanings of RFC 2119.

## A spot

A spot is one file and one loop:

```text
event   ─ on= ─►  <script> read          Openspot calls the script
script  ─ prints ─►  frames of blocks    Openspot draws them
press   ─ on a block ─►  <script> <id>    a person or an agent acts
```

- A spot is one executable file, in any language, at the top of the plugins folder or one folder down.
- Its ID is its path with no extension, such as `home/coffee`. One file gives one spot.
- A spot of more than one file MUST live in a folder of its own, one folder down. The folder is one unit: it is shared
  whole, and its scripts share one data folder.
- A file that is not executable MAY hold shared code.
- The spot says what it has. Openspot and the person decide where, when and on which key it shows.
- A person or an agent makes the same calls. An agent presses through `openspot spot run <id> <call>`, and raises events
  through `openspot event emit`. The spot cannot tell which one called.

## Your first spot

The smallest spot is a script. A click runs it.

```sh
#!/bin/sh
say hello
```

Comment lines at the top give it a name and a picture.

```sh
#!/bin/sh
# title=Morning
# icon=sun.max
open -a Calendar
```

An `on=` line says when Openspot reads it, and the script prints what to show.

```sh
#!/bin/sh
# title=Cups today
# icon=cup.and.saucer.fill
# on=sheet.open
printf 'text=cups\ntitle=3\ndetail=Last at 14:20\n'
```

## Try your spot

Run each example of this page in the playground before you put it in the plugins folder.

- **The playground.** Open the Playground spot, or run `openspot sandbox [file]`. Type a spot, or pick one from Examples,
  and see its sheet, its card and each call: its arguments, its stdin, each frame, its stderr and how it ended. A file
  that you name stays in step with the editor.
- **A start.** `openspot spot new <name> --from <kind>` writes a working spot to change: `button`, `list`, `number` or
  `form`.
- **One call.** `openspot spot run <id> [call] [value]...` makes one call as Openspot does, and prints all that the spot
  prints. With no call, it reads the spot.
- **A picture.** `openspot render [--view <file>] <file.png>` draws the sheet that stdin holds. `--card <size>` draws its
  card, and `--spot <id>` draws an installed spot.
- **The last calls.** `openspot spot log <id>` prints the last calls that Openspot made to a spot, with their stdin,
  stdout, stderr and exit code.
- **The check.** `openspot check [--json] <folder>` loads and reads each spot, and prints each fault. Run it before you
  stop.

## The format

Everything that a spot prints, and its header, is lines of `key=value`.

```ini
text=title
title=Wi-Fi
detail=Home · 82 Mb/s

switch=wifi
value=true
---
```

- A line is `key=value`. It splits at its first `=`.
- A blank line ends a block. A line `---` ends a frame.
- In a value, `\n` is a new line and `\\` is a backslash. There are no other escapes.
- An empty value is no value. A value is never split again, so a URL or a time stays whole.
- Only a list of plain words splits at commas, such as `uses=screen,clipboard`.
- The first key of a block names its kind, and its value is the id of the block.
- The one block whose first key names no kind is the head.
- Openspot skips a line with an unknown key.
- A thing with its own title or picture is a block of its own, such as an `option` after a `choice`.

## The header

The header says what a spot is, without a run. It is a frame in comments.

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

- The comment lines right under the first line are the header. They start with `#`, `//` or `--`. The first other line
  ends them.
- The keys of the spot come first. After each blank comment line comes a `button` or a `field` block.
- Openspot reads the header and never runs a spot to scan it.
- A header key that is not valid refuses that spot. The other spots still load.

| Key           | Value                                                                                                            |
| ------------- | ---------------------------------------------------------------------------------------------------------------- |
| `title`       | The name. The default comes from the file name.                                                                  |
| `icon`        | The picture, as for a block. A path that does not start with `/` starts at the folder of the script.             |
| `detail`      | The second line.                                                                                                 |
| `keyword`     | One more word that finds it in the main search. It MAY repeat.                                                   |
| `on`          | An event that reads it, with a filter of its value. It MAY repeat. See Events.                                   |
| `emits`       | The events that it raises, split by commas. See Events.                                                          |
| `offers`      | `search`: its rows show in the main search. See Places.                                                          |
| `drop`        | The files that its card takes: extensions such as `mov,mkv`, `folder`, or `*`.                                   |
| `size`        | The size it prefers: `wide` (the default), `small`, `square`, `strip` or `large`. The person's choice wins.      |
| `preview`     | `sample`: a read with `OPENSPOT_REASON=spot.preview` prints fake data for the store.                             |
| `view`        | A SwiftUI file beside the script, such as `view=cups.swift`. See Views.                                          |
| `mode`        | `once` (the default), `stay` or `always`. See Modes.                                                             |
| `uses`        | What it uses, split by commas: `app`, `spots`, `screen`, `clipboard`, `calendar`, `network`, `files`. See Trust. |
| `grid.<size>` | A card drawn from other spots: each word is the ID of a spot, not a block. See Cards of other spots.             |
| `to`          | The spot that a press of a card of other spots opens.                                                            |

| Block         | Meaning                                                                                              |
| ------------- | ---------------------------------------------------------------------------------------------------- |
| `button=<id>` | A command that the person can give a key, with its `title` and its `icon`.                           |
| `field=<key>` | A value that the person chooses, with its `title` (its key by default) and its `icon`. See Settings. |

- A spot with a `button` block in its header has no card on the grid. Its commands are what it gives.

## Frames

A frame is one picture of the spot, or one set of effects. A call can print many.

```sh
#!/bin/sh
# title=Copy
# on=sheet.open
printf 'progress=0.5\ntitle=Copying\n---\n'
printf 'text=done\ntitle=Copied\n'
```

- Openspot draws each frame at once.
- The spot holds no state. Each call gets the values on stdin and prints the whole output again, or nothing.
- A frame with a block is the whole picture. It replaces all that the spot shows.
- A frame of only a head changes no picture, and its effects act (see The head).
- A read that ends with no picture shows nothing. Another call that ends with no picture makes Openspot read the spot once.
- Openspot drops the answer to a call that a newer change has outdated.
- A value from data MUST go through a helper: `openspot_kv`, `openspot_row` or `esc` in a shell, and `openspot.frame` in
  JavaScript, so that a value never adds a line or a block. `openspot check` warns of a block with a line that has no
  `=`, or with a key twice that only a list repeats.
- Openspot reads `ESC ] 9;4;1;<percent>` as `progress` and `ESC ] 9;<text>` as a toast, and removes each other escape
  code.

## Blocks

A block is one thing on the sheet or the card: words, a number, a switch, a row.

```ini
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

button=forget
title=Forget
shortcut=cmd+backspace
confirm=Press again to forget
```

- A spot prints blocks, and a drawing places them. The app owns each canvas, size, gap and colour.
- A block is `<kind>=<id>`. The id names its area, the call that it sends, and the thing that moves when it changes. Ids
  MUST be unique in one output.
- Each kind keeps its data in `value`. A kind that shows several values repeats it.

| Kind      | Shows                                                                                                          | Its own keys                                                         | Sends                  |
| --------- | -------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------- | ---------------------- |
| `text`    | Words, and a small mark: a bar from `value`, or with `max` a bar for each `value` line.                        | `value`, `max`                                                       |                        |
| `number`  | A big number, with its `title` under it. `display` shows in place of `value`.                                  | `value`, `display`                                                   |                        |
| `graph`   | One `value` from 0 to 1 is a ring in a square area and a bar in a wide one. More are bars, the newest last.    | `value`, and `max` for bars                                          |                        |
| `picture` | A picture that fills its area.                                                                                 | `icon`                                                               |                        |
| `view`    | The SwiftUI view that the header names (see Views).                                                            | any key that the view reads                                          |                        |
| `switch`  | A switch, or with `type=tick` a round tick before its words, for a thing to do.                                | `value`: `true` or `false`, `type`                                   | `<id> true` or `false` |
| `field`   | A text field, or with a `type` another input.                                                                  | `value`, `type`, `placeholder`, `required`, `readonly`, `min`, `max` | `<id> <value>`         |
| `choice`  | A menu of the `option` blocks after it, a list when it covers two lines or more, or swatches of `color` lines. | `color`, `value`, `type`                                             | `<id> <option id>`     |
| `option`  | One choice of the `choice` right before it.                                                                    | `title`, `icon`                                                      |                        |
| `button`  | A button, or an action (see Buttons and actions).                                                              | `shortcut`, `confirm`, `close`, `look`, `form`, `scope`              | `<id>`                 |
| `section` | A title over the lines that follow it.                                                                         |                                                                      |                        |
| `repeat`  | The rows of the output (see Rows).                                                                             | `grid` lines                                                         |                        |
| `row`     | One item of a list (see Rows).                                                                                 | the keys of Rows                                                     | `open <id>`            |

- The `type` of a field: none for a line of text, `multiline` for several lines, `slider` from `min` to `max` (0 to 100 by
  default), which sends when the person lets go, and `hotkey` for a key combination that a press records.
- `type=multiple` lets a choice pick several (see Buttons and actions).
- Each kind also takes `title`, `detail`, `tone` and `icon`. A key that a kind does not take is skipped.
- `icon` says what the picture is by its value:
  - a path of a picture file, such as `cups.png`, draws the picture;
  - an `https://` URL draws a picture from the web, which Openspot fetches once and keeps;
  - any other path draws the Finder icon of the file;
  - a name of lowercase letters, digits and dots, such as `wifi`, is an SF Symbol;
  - any other text, such as `😀`, is drawn as it is.
- `tone` is `good`, `warn` or `bad`. On a text, it colours the detail, or the title when it has no detail.
- `color=#RRGGBB` on a text or a number draws a thin bar of that colour at its leading edge.
- `look` is the box of a text, a number or a button: `tile` or `bare`, and on a button also `chip` or `strong`.
- `align=left`, `right` or `center` places a block that is smaller than its cell.

## Drawings

A drawing says where each block goes, as CSS grid areas do.

- Each `grid=` line of the head is one line of the sheet. Each word is one cell: the id of a block, `.` for an empty cell,
  or `-` for a divider across the line.
- The words of a line set the columns. A block fills the rectangle of cells that its id covers, and each id MUST cover a
  rectangle. A smaller block in a larger one sits on top of it, at the edge that it touches.
- `grid.<size>=` lines draw the card at a size: `small`, `wide`, `square`, `strip` or `large`. A block that only a card
  drawing places shows only on the card.
- In a header, the words of `grid.<size>=` lines are the IDs of other spots, not blocks (see Cards of other spots).
- A card drawing MAY have more lines than the card has rows. A size with no drawing takes the drawing of the nearest
  smaller size. A spot with none keeps its default card.
- With no `grid=` line, the sheet shows each block that is not a button in one column, in print order, then its rows. A
  `section` starts a new group.

## Buttons and actions

A button is a verb. Placed in a drawing it is drawn; left out, it is an action in the ⌘K menu.

```sh
#!/bin/sh
# title=Notes list
# on=sheet.open
. "$OPENSPOT_SH"
case "$1" in
  read)
    openspot_row today Today
    printf '\nbutton=trash\ntitle=Move to Trash\nshortcut=cmd+backspace\nconfirm=Press again to delete\n'
    ;;
  trash) rm -f "$OPENSPOT_DATA/$2" ;;
esac
```

- An action with no row selected acts on the whole spot. An action on a row is `<script> <id> <row id>`.
  `scope=command` keeps it on the whole spot.
- `close=true` closes the panel after it runs. `confirm` asks for a second press.
- `shortcut=escape` presses the button in place of closing the sheet, such as a Cancel.
- In a ⌘K menu of more than 5 rows, a field searches them, so only a `shortcut` with `cmd` runs an action there.
- Enter on a row is the action `open`. `button=open` gives it its word with `title`, and `close=false` keeps the panel
  open after a pick.
- A button with `form=true` asks for values first. The call runs once with empty stdin, and prints a `title` in its head and
  one `field`, `choice` or `switch` for each value. Then the same call runs with the values on stdin.
- A form with one `choice` and nothing else shows its options as rows under the search field. Enter or a click sends one.
- With `type=multiple`, the choice picks several: a checkmark marks each option of a `value` line, Enter sends the option
  of its row, and `⌘⇧A` sends each option with no checkmark. The spot keeps the picks and prints the form again.
- A form MAY print itself again, such as with a `title` that says what is wrong. Then it stays open.

## Rows

Rows are a list that the person searches and picks from.

| Key        | Meaning                                                                                     |
| ---------- | ------------------------------------------------------------------------------------------- |
| `row`      | The id. A pick sends `<script> open <id>`.                                                  |
| `title`    | The first line. The id, when it has none.                                                   |
| `detail`   | The second line.                                                                            |
| `icon`     | The picture.                                                                                |
| `parent`   | Where it sits in its spot. The main search shows `<spot> › <parent>`.                       |
| `tone`     | A dot of its colour on the picture.                                                         |
| `value`    | `true` draws a checkmark at the end.                                                        |
| `hides`    | The id of an action that this row does not offer. It MAY repeat.                            |
| `keyword`  | A word that finds the row and does not show.                                                |
| `shortcut` | A key that shows at the end of the row.                                                     |
| `type`     | `hotkey`: a pick records a new key and calls `<id> <shortcut>`.                             |
| `shake`    | `true` lets a shake of the pointer be the key that a pick records, as `<id> shake`.         |
| `file`     | The file that the row stands for. See Files out.                                            |
| `to`       | Another spot that a pick goes to, as `<spot> open <row id>` with the row's fields on stdin. |

- Rows flow through a `repeat`, or through a list when there is none.
- Openspot searches the rows itself and puts recent picks first. `recents=false` in the head turns that off.
- With `on=sheet.text`, each change of the search of the sheet is a read, and the spot prints the rows that match. It also
  reads the spot when its sheet opens, as `on=sheet.open` does. A pick
  gets the text on stdin as `search=<text>`. A read at any event gets the typed text too.
- A `repeat` has its own `grid=` lines, in which each word is the place of one row. The drawing repeats down for as long
  as there are rows. Rows take the places in the order in which each word first shows.

```ini
repeat=photos
grid=a a b c
grid=a a d e
```

- A row draws its `icon`, `title`, `detail`, `tone`, `value` and `shortcut`. A row that needs more offers it as an action,
  or the spot draws it with a `view`.

## The head

The head is the one block with no kind. It is not drawn: it holds the drawing and the effects.

- Its picture keys: `grid=` and `grid.<size>=` lines, `main`, `title` and `detail` for the card, and `recents`.
- Its effects: `toast`, `link=<url>`, which opens the URL, `progress=<0 to 1>`, `end=<call>` of a staying spot, and
  `select=<row id>`, which reads again with that row selected. With `progress`, its `title` and `detail` show only while the
  call runs.
- `toast=Saved` shows at once, also with the panel closed.
- A second block with no kind is skipped and reported.

## The main block and the card

One block stands for the spot on its card and in the menu bar.

- `main=<id>` in the head names it. With no `main=`, the only `text`, `number`, `graph`, `switch` or slider of the output
  stands for it.
- The menu bar and a card of other spots show a main `text`, `number` or `graph`. A main `switch` shows on the card whether
  its thing is on.
- With no `grid.<size>=`, a spot draws its default card: its picture, title and detail, and an arrow when it has a sheet.
- A spot whose output is one `switch` or one slider draws that block as its card, and a press of the card changes it.
- A press on a card area that is not a control opens the sheet, or calls `<script> open` when it has none.

## Events

An event is what makes Openspot read a spot. The header lists the events that are safe to read on.

```sh
#!/bin/sh
# title=Notes
# on=sheet.open
# on=app.front com\.apple\.Notes
```

- An event is a word `<noun>.<verb>`. It MAY carry a value: the table gives the value of each event that Openspot raises,
  and `openspot event emit` gives the value of any other.
- Each `on=` line names one event that reads the spot. The text after a space is a filter: a regular expression that the
  value of the event MUST match.
- A filter works only on an event that carries a value: `search.text`, `app.front`, `app.update` or an event that a spot
  emits. A filter after any other event is a fault. `sheet.text` also takes none, because the spot answers each text of
  its sheet.
- A spot with no event is never read. A click runs `<script> open`.
- Each read gets the event in `OPENSPOT_REASON` and its value in `OPENSPOT_VALUE`.

| Event              | Openspot raises it                                                        | Value         |
| ------------------ | ------------------------------------------------------------------------- | ------------- |
| `sheet.open`       | When its sheet opens.                                                     |               |
| `panel.open`       | Each time the panel opens, and once as the app starts.                    |               |
| `clock.<seconds>`  | Every that many seconds while something wants it, and when the Mac wakes. |               |
| `search.text`      | At each change of the text of the main search.                            | the text      |
| `sheet.text`       | At each change of the text of the search of its sheet, and when it opens. | the text      |
| `clipboard.change` | When the clipboard changes.                                               |               |
| `app.front`        | When another app comes to the front.                                      | its bundle ID |
| `app.update`       | When the app has downloaded an update.                                    | its version   |
| `screen.wake`      | When the screen wakes.                                                    |               |

- Openspot also reads a spot with these reasons, which are no events:
  - `spot.change`: after a call that printed no picture;
  - `spot.want`: when something starts to want a spot that no event read yet;
  - `spot.preview`: for the preview of the store.
- `openspot event emit <event> [value]` raises an event in the running app, from a spot or a terminal. With the app
  closed, it starts the app first.
- A spot MUST name each event that it raises in `emits`, such as `emits=music.track`. `openspot check` reports an `on`
  event that Openspot does not raise and that no spot names in `emits`.
- A read MUST NOT raise the event that caused it. `openspot check` warns of a spot whose `on` and `emits` share a name.
- Something wants a spot while its sheet, a card of other spots or the menu bar shows it, or while the open panel reads it
  at `panel.open`.
- A `clock` and the events other than `open` and `text` read a spot only while something wants it. `app.update` reads
  each spot that lists it, wanted or not.
- A read MUST be safe at each event that its header lists. Only its author can promise this. A spot has one read at a time.

## The calls

A call is how Openspot asks a spot to do one thing. It has the shape of a CGI call.

```sh
#!/bin/sh
# title=Today
# on=sheet.open
. "$OPENSPOT_SH"
case "$1" in
  read) openspot_row today Today ;;
  open) open -a Notes ;;
esac
```

| Call                                 | When                                                 |
| ------------------------------------ | ---------------------------------------------------- |
| `<script> read`                      | An event that its header lists.                      |
| `<script> open [row id]`             | A row is picked, or a card with no sheet is pressed. |
| `<script> <id> [row id] [value]`     | A block changes or is pressed.                       |
| `<script> drop <path> [path]...`     | Files are dropped on its card.                       |
| `<script> drag <row id> [row id]...` | Rows that hold files are dragged out of its sheet.   |
| `<script> <command>`                 | A key that the person gave a command is pressed.     |

- `read` is the only reserved call. `open`, `drop` and `drag` are default ids. A block MUST NOT use one, but a button MAY
  use `open`.
- A new default id reaches only a spot that asks for it.
- A drop on a card with a running call waits for that call. A drop on a card with rows opens its sheet, and the answer MAY
  select the new row with `select=`.
- The presses of the keys of one spot run one at a time, in order, and never stop a call. Only the person gives a command
  its key.

A call has three parts in each mode:

- **Arguments:** the id, its row, then its values, so that `case "$1"` handles each call. A value over 64 KB goes on stdin
  only.
- **Variables:** `OPENSPOT_REASON` and `OPENSPOT_VALUE` of a read, `OPENSPOT_ID`, the ID of the spot, `OPENSPOT_DATA`, a
  folder for its files that one spot folder shares, `OPENSPOT_SH`, the shell helper, and `PATH`, with the `openspot`
  command first.
- **Stdin:** one block of what the person filled in and typed: a line for each field of the sheet, `search=` with the typed
  text, and a `form=` line for each other text that the person may have meant, such as the same keys in another layout.
  A value that is not a field comes as `value=`.

```ini
title=Groceries
search=milk
form=ьшдл
```

The shell helper writes values for you:

| Function                                    | Does                                                                                              |
| ------------------------------------------- | ------------------------------------------------------------------------------------------------- |
| `esc <text>`                                | Prints text as a value.                                                                           |
| `value <id>`                                | Prints each value of the key from stdin, one per line, in order.                                  |
| `openspot_kv <key> <value>`                 | Prints one line, with its value written for you.                                                  |
| `openspot_row <id> <title> [detail] [icon]` | Prints one row.                                                                                   |
| `openspot_rows [kind]`                      | Prints a row, or a block of that kind, for each tab-split line of stdin: id, title, detail, icon. |
| `openspot_serve <function> "$@"`            | Runs the function with the three parts of each call, in each mode.                                |

- Loading the helper reads all of stdin, except in a staying spot.

```sh
#!/bin/sh
. "$OPENSPOT_SH"
printf 'field=output\n'
openspot_kv value "$(value input)"
```

## The life of a call

A call starts, prints, and ends. These rules say how long it may take and what a stop does.

- A `read` has 10 seconds until its first frame or its end. Any other call has no time limit.
- A new value for a block stops the older call of that block. A second press of a running call stops it: its process group
  gets the terminate signal, then the kill signal. Quitting Openspot stops each call.
- A call ends when its output closes. A stopped call changes nothing.
- Exit 0 is success. Any other code is a failure, and the last line on stderr shows to the person. A failure MAY print
  `link=<url>`, the place that fixes it.
- A failed read at `panel.open` only marks its card and goes to the app log.
- A stop can come at any time, and two calls can run at once. A spot MUST NOT leave a file half written.

## Places

The person decides where a spot shows. A spot only offers.

```js
// title=Calculator
// icon=equal.square
// on=search.text ^[0-9(]
// uses=clipboard
function main(args, env) {
  if (args[0] === "read")
    return openspot.call(["calc", "solve", env.OPENSPOT_VALUE]).stdout;
  return "";
}
```

- The person gives each spot its letter, puts spots in the menu bar, floats them, and orders and sizes the cards. A spot
  MUST NOT claim a letter or a place.
- `offers=search` shows the rows of the spot in the main search. It needs `on=panel.open` or a `clock`. Openspot ranks the
  rows by the person's picks.
- The person MAY give any spot with a sheet a key or a shake of the pointer in Settings. It shows the spot in a small window
  at the pointer, which stays while the person works in other apps. The spot never learns where it shows.
- `on=search.text <pattern>` makes a spot answer the main search. Openspot reads it at each change of a text that the
  pattern matches, with no pause. A newer text stops the older call. The answer SHOULD be fast.
- Its rows show first in the main search until the newest text is answered, and go at once when the pattern no longer
  matches. A pick of a row is `<script> open <row id>`.
- A spot whose only event is `search.text` has no card.
- An answer MAY be one card in place of its rows: its head draws `grid.large=` or `grid.strip=`, and its main block has a
  `value`. A pick of the card is `<script> open <value>`.
- `openspot calc solve <words>...` prints the answer of a sum, a conversion or a date as a row.
- A spot with a `clock`, another event, or `mode=stay` or `always`, and a main `text`, `number` or `graph`, MAY show in the
  menu bar when the person puts it there. A read that prints nothing hides it until the next read.
- A spot with a `clock` has no card on the grid until the person shows it.

## Modes

A spot runs once for each call, unless its header says otherwise.

- `mode=once` starts a process for each call.
- `mode=stay` keeps one process that takes each call on stdin while something wants it.
- `mode=always` keeps that process from the start of the app to its quit.
- A `.js` file with a header runs inside the app, and one with no header MAY hold shared code. An executable `.js` file runs
  as a process, like any other script.

### A JavaScript spot

```js
// title=Hello
// on=sheet.open
function main(args, env, input) {
  if (args[0] === "read")
    return openspot.frame({
      row: "hi",
      title: `Hello from ${env.OPENSPOT_REASON}`,
    });
  return "";
}
```

- The file defines `main(args, env, input)`, which gets the three parts of a call, and returns the text of a frame.
- `openspot.call(["calc", "solve", "2+2"])` runs the openspot command and returns `{ stdout, code }`. A second argument
  gives its stdin.
- `openspot.frame(object)` writes an object, or a list of objects, as blocks.
- It has no files, no network and no process of its own. It runs one call at a time on a thread of its own.
- Openspot waits 2 ms for its frame in the turn of the key, and shows a later frame in the next turn.
- A call has 10 seconds. Then it fails as a slow read, and the spot answers its next call.

### A staying spot

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

Openspot writes each call to its stdin as one block, then a blank line: `call=<n>` numbers it, an `arg` line gives each
argument, an `env.<name>` line gives each variable, and one `input` line holds its stdin.

```ini
call=4
arg=send
env.OPENSPOT_REASON=panel.open
input=peer=127.0.0.1:47800\nmessage=Hello\n
```

- A staying spot is one process that talks both ways over stdio. Each call reaches the running process, and no call starts
  a second copy.
- `openspot_serve main "$@"` runs `main` with the three parts of each call, prints `call=<n>` before its output and
  `end=<n>` after it. One `main` runs unchanged in each mode.
- The spot MAY print frames at any time. It MUST end each call with `end=<n>` in a head. A frame of only `call=<n>` starts
  the output of that call.
- A second press sends the block `stop=<n>`. A newer text sends `stop=<n>` for the read of the older one, so only the
  answer to the newest text shows. A read after the first gets `stop=<n>` after 10 seconds and fails as a slow read.
- With `mode=stay`, it runs while something wants it, or while a call waits for its `end`. When nothing wants it, Openspot
  closes its stdin, and the spot MUST end, with each process that it started. After 2 seconds its process group gets the
  terminate signal, and 2 seconds later the kill signal.
- After 3 failures in one minute, Openspot tells the person, and starts it again only when its file changes. What must
  survive SHOULD go in `OPENSPOT_DATA`.

### A Swift script

- A Swift file with `#!/usr/bin/env swift` on its first line is a script, with its header in `//` lines.
- It needs the Command Line Tools. Openspot builds it once, and again when the file changes.

## Views

A view draws what the blocks cannot: a SwiftUI view of the spot in an area.

```sh
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

- `view=<file>` in the header names a SwiftUI file beside the script. A `view=<id>` block draws it in its area.
- The spot and its view MUST lie in a folder of their own, such as `cups/cups.sh` and `cups/cups.swift`.
- The file declares `struct SpotView: View` with `let spot: SpotInput`, and has no top-level code.

| Member            | Gives                                                            |
| ----------------- | ---------------------------------------------------------------- |
| `spot["key"]`     | The last value of a key of its block, or nil.                    |
| `spot.all("key")` | Each value of a key that repeats.                                |
| `spot.size`       | The size of its area.                                            |
| `spot.inset`      | The space that other cards keep between their edge and words.    |
| `spot.corner`     | The corner radius of the card.                                   |
| `spot.ink`        | The colour of words, for light and dark.                         |
| `spot.secondary`  | The opacity of a second line.                                    |
| `spot.accent`     | The accent colour.                                               |
| `spot.font`       | The fonts of the cards: `title`, `detail`, `metric` and `value`. |

- The view fills its area, and with no card drawing the whole card. It cannot change the size of its area.
- It gets the keys of its block in each frame. A new frame keeps its `@State`.
- The view only draws. A press works as on any card.
- Openspot compiles it when its card first shows, and again when the file changes. A view that does not compile shows its
  first error, and `openspot check` prints it.
- A shared spot carries the compiled view as `<name>.view`, which Openspot uses in place of the source.
- The view runs inside Openspot, so a crash quits Openspot. The work SHOULD be in the spot, and `body` SHOULD only draw.

## Cards of other spots

A card can show several spots at once. The spot that draws it names them, and Openspot passes their data.

```sh
#!/bin/sh
# title=System
# grid.large=battery battery cpu cpu
# grid.large=battery battery memory memory
# to=system-info
```

- Each word of the `grid.<size>=` lines of a header is the ID of a spot. Openspot reads each spot that it names while the
  card shows, and shows its main block in that area.
- A spot that a card names MUST have an `on=` event. With no event that reads it, Openspot reads it with `spot.want`.
- A metric is a spot with a `clock` whose main block is a `text`, a `number` or a `graph`.
- A name is a script of its own folder first, else the ID of a spot.
- The lines of one drawing MUST have the same number of words, and each name MUST cover a rectangle. A drawing MUST use one
  size.
- `to=` names the spot that a press of the card opens.

## Files out

A row can stand for a file that the person drags into another app.

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

- A row with `file=<path>` stands for that file. The person can drag it into any app that takes files. The path MUST
  start with `/`.
- The other app copies or moves the file. A read SHOULD leave out each file that no longer exists.
- When a drop ends in another app, Openspot calls `<script> drag <row id>...`. A drag with no drop sends nothing. With no
  answer, Openspot reads again.
- A drag of the picture in the head of the sheet drags each row that has a `file`.

## The openspot command

A spot asks the Mac and the app through one command, which works the same in a terminal.

- A capability is `openspot <noun> <verb>`.
- A noun names its commands, its events and its use together, such as `openspot clipboard copy`, `clipboard.change` and
  `uses=clipboard`.
- A call that reads files or asks the Mac gives the same answer with the app or without it. A call that needs the running
  app starts it, and waits up to 10 seconds.
- Ctrl-C stops a call, and the stopped work changes nothing.
- `openspot help` lists each capability. `openspot help <noun>` prints the guide of a noun, such as `screen` or `calendar`.
- A capability that cannot answer prints `status=<word>`. One that keeps state keeps it in its own helper.
- When macOS already has a command, such as `open`, use it. For the screen and the clipboard, use `openspot screen` and
  `openspot clipboard`, so that the person sees each use.
- A command that waits for the person, such as `openspot color pick` or `openspot folder pick`, fails in a read.
- A call that changes the Mac, ends the app or opens the panel fails in a read.
- `openspot batch` runs one call per line of stdin and prints `---` after each. It stops at the first failure.
- `--frame` makes `app status`, `spot list` and `setting list` print blocks in place of JSON.

The commands that try a spot are in Try your spot. The others:

| Command                                            | Does                                                                                      |
| -------------------------------------------------- | ----------------------------------------------------------------------------------------- |
| `openspot guide`                                   | Prints this page.                                                                         |
| `openspot spot show <id>`                          | Opens the panel with the spot selected.                                                   |
| `openspot spot add <git url, folder or file.spot>` | Adds a spot, and records it in `spots.lock`. An update that grows its uses needs `--yes`. |
| `openspot spot remove <id>`                        | Moves a spot that `spot add` added to the Trash.                                          |
| `openspot spot stats`                              | Prints what each spot cost and used. See Stats.                                           |

### Settings

A setting is a choice of the person that a spot keeps.

```sh
#!/bin/sh
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

- A `field` block in the header names a value that the person chooses. The Settings spot lists it, set or not.
- Enter on it runs the action of the same name, which MAY answer with a form. `⌘⌫` removes the value.
- `openspot setting get <key>` prints the value, or nothing. `openspot setting set <key> [value]` keeps it, or removes it
  with no value. `--spot <id>` names the spot from a terminal.
- A choice of the person SHOULD go in a setting. What the spot makes, such as a cache, SHOULD go in `OPENSPOT_DATA`.
- Openspot keeps some keys for the person, and a `field` MUST NOT use one. Of any spot: `enabled` and `menubar`, `true` or
  `false`, and `float` and `key.<command>`, a key such as `ctrl+option+k` or `shake`, or none to take it away. Of the spot
  `openspot`, which is the app: `login`, `link` and `careful`, `true` or `false`, and `panel-key` and `fix-key`. Each
  needs the use of the call that does the work (see Trust).

### Stats

Openspot counts what each spot cost and used, so that the person can see it.

```sh
openspot spot stats --days 7 --frame
```

- Openspot keeps one file for each day, for 90 days. Today's numbers are live.
- `--days N` sums the last N days. `--spot <id>` keeps one spot.
- `--frame` prints a `row=<id>` block for each spot, the most CPU first, then a `use=<n>` block for each call that needs a
  use, the newest first.

| Row key              | Meaning                                                               |
| -------------------- | --------------------------------------------------------------------- |
| `title`, `detail`    | The name of the spot, and its numbers in words.                       |
| `runs`, `failures`   | The calls that ended, and those that failed.                          |
| `cpu`, `seconds`     | The CPU seconds of its processes, and the wall time of its calls.     |
| `read`, `written`    | The bytes that its processes read and wrote.                          |
| `wakeups`            | The times its processes woke the CPU.                                 |
| `call.<noun>.<verb>` | The count of one call that needs a use, such as `call.screen.shot=2`. |
| `network`            | `declared` when its header names `network`.                           |
| `fault`, `tone`      | Its last fault, with `tone=bad`.                                      |

- A `use` block holds `time`, `spot`, `call`, such as `app.quit`, and `declared`, `true` or `false`.

## Trust

A spot runs with the person's rights. Openspot shows what it can do, and what it did.

```sh
#!/bin/sh
# title=Coffee
# uses=app
openspot app quit
```

- Openspot asks nothing in daily use. It shows what a spot can do when the person adds or updates it, and shows each use
  after it happens.
- Openspot knows which spot makes each call of `openspot`, from its own record, not from the variables of the process.
  Only the person's own processes reach the socket of the API.
- `uses` names what a spot uses. An unknown word refuses the spot.

| Use         | The calls that need it                                                                                                                                     |
| ----------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `app`       | `app quit`, `update check`, `update install`, and `setting set` of `menubar`, `float`, `key.<command>` or of the spot `openspot`                           |
| `spots`     | `spot add`, `spot remove`, `spot new`, `spot run`, `spot log`, `setting list`, `setting set` of `enabled`, and `setting get`, `set` or `change` of another spot|
| `screen`    | `screen sources`, `screen shot`, `screen record`, `window frame`, `window move` and `color pick`                                                           |
| `clipboard` | `clipboard copy`, `clipboard paste` and `clipboard read`                                                                                                   |
| `calendar`  | each call of `calendar` and `reminders`                                                                                                                    |
| `network`   | No call. The spot reaches the network.                                                                                                                     |
| `files`     | No call. The spot writes outside its data folder.                                                                                                          |

- A call that needs a use that the header does not name still runs, and shows one toast for each spot, use and day.
  `openspot check` does not report it, because only a run shows it.
- Before an add, the review shows the title, the `uses`, and a line `Can also` with what the text seems to do and does not
  name: the network, `rm`, `screencapture`, `pbcopy` or `pbpaste`. It warns and never refuses.
- An update with no new use applies quietly. One with a new use waits for `--yes`.
- Careful mode is a setting of the person, off by default. It runs each process of a spot in a sandbox: no network unless
  `uses=network`, writes only to its data folder and the temp folders unless `uses=files`, and also to the Desktop, Movies
  and the screenshots folder with `uses=screen`. In Careful mode, a call of a use that the header does not name fails.
- Without Careful mode, the data folder is no boundary.

## Messages

A toast or a failure line says what happened, and why when you know it. It says what still worked, and the exact step that
fixes the rest. Use plain words, a calm tone, and one or two short sentences, with each key in backticks.

| Instead of                    | Write                                                                                  |
| ----------------------------- | -------------------------------------------------------------------------------------- |
| `Oops! Something went wrong.` | `Openspot cannot find a screenshot.`                                                   |
| `Error 1: osascript failed.`  | ``Copied, but Openspot cannot paste. Press `⌘V`, or allow Openspot in Accessibility.`` |

## Versions

The version at the top is the version of this contract. A new word raises its minor number, such as `1.1`. A draft becomes
`final` when a real use proves it, and a final version never changes the meaning of a word. A change that breaks an old
spot raises the major number and adds a header key `protocol=<major>`. A spot with no such key is version 1.

## How to extend

An old spot never sees a word that it did not ask for, and an old app skips a word that it does not know.

| To add               | Add                                                              |
| -------------------- | ---------------------------------------------------------------- |
| A thing that happens | an event `<noun>.<verb>`                                         |
| A thing to draw      | a kind `<kind>=`, which an old app skips and reports             |
| A detail of a kind   | a key, or a `type` value                                         |
| A power of the Mac   | a noun: `openspot <noun> <verb>`, its events and its `uses` word |
| A complex look       | nothing: a `view` of the spot                                    |
