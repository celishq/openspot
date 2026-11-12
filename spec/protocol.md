# Openspot protocol

`1.0` `draft`

Openspot runs small programs called spots. A spot prints what to show. Openspot draws it, and runs the spot again when
something happens. This page is all you need to write one. Start with [Your first spot](#your-first-spot), and read the
rest when you need it.

## A spot

A spot is one file and one loop:

```text
event   ─ on= ─►  <spot> read           Openspot runs the spot
spot    ─ prints ─►  frames of blocks   Openspot draws them
press   ─ on a block ─►  <spot> <id>    the user or an agent acts
```

- A spot is one executable file, in any language. It lives at the top of the plugins folder, or one folder down.
- Its id is its path without the extension, such as `home/coffee`.
- A spot made of several files lives in a folder of its own, one folder down. Openspot shares the folder as one unit, and
  its spots share one data folder.
- A file that is not executable can hold shared code.
- A spot says what it has. The user decides where it shows and which key opens it.
- An agent makes the same calls as the user. It presses with `openspot spot run <id> <call>` and raises events with
  `openspot event emit`. A spot cannot tell who called it.

## Your first spot

The smallest spot is a script. A click on its card runs it.

```sh
#!/bin/sh
say hello
```

Comment lines at the top give it a name and an icon.

```sh
#!/bin/sh
# title=Morning
# icon=sun.max
open -a Calendar
```

An `on=` line says when Openspot reads the spot. The spot then prints what to show.

```sh
#!/bin/sh
# title=Cups today
# icon=cup.and.saucer.fill
# on=sheet.open
printf 'text=cups\ntitle=3\ndetail=Last at 14:20\n'
```

## Try your spot

Run each example of this page in the playground before you put it in the plugins folder.

- **Playground.** Open the Playground spot, or run `openspot sandbox [file]`. Type a spot, or pick one from Examples. Pick
  where it shows: its sheet, its card, or the main search. Below, you see each call: its arguments, its stdin, each
  frame, its stderr, and how it ended. When you name a file, the editor and the file stay the same.
- **New spot.** `openspot spot new <name> --from <kind>` writes a working spot that you can change. The kinds are
  `button`, `list`, `number` and `form`.
- **One call.** `openspot spot run <id> [call] [value]...` makes one call as Openspot does, and prints all that the spot
  prints. With no call, it reads the spot.
- **Image.** `openspot render [--view <file>] <file.png>` draws the sheet that stdin holds. `--card <size>` draws the card,
  and `--spot <id>` draws an installed spot.
- **Log.** `openspot spot log <id>` prints the last calls to a spot, with their stdin, stdout, stderr and exit code.
- **Check.** `openspot check [--json] <folder>` loads and reads each spot, and prints each error. Run it before you
  finish.

## Words

This page uses each word in one meaning only.

| Word       | Meaning                                                                                                   |
| ---------- | --------------------------------------------------------------------------------------------------------- |
| **spot**   | One executable file that Openspot runs.                                                                   |
| **user**   | The person who uses Openspot.                                                                             |
| **panel**  | The window of Openspot: the main search, and the grid of cards under it.                                  |
| **card**   | A spot on the grid of the panel.                                                                          |
| **sheet**  | The view of one spot, which opens over the panel when the user presses its card.                          |
| **header** | The comment lines at the top of a spot. Openspot reads them without running the spot.                     |
| **call**   | One run of a spot with arguments, such as `coffee.sh read`.                                               |
| **read**   | The call `<spot> read`, which asks the spot what to show.                                                 |
| **event**  | A thing that happens, such as `sheet.open`. An event makes Openspot read the spots that list it.          |
| **block**  | One thing that a spot shows, such as a text, a switch or a row. It is a group of lines.                   |
| **frame**  | All the blocks that a spot shows at one time. Each new frame replaces the last one.                       |
| **head**   | The block of a frame that holds its layout and its effects, such as a toast. Openspot does not draw it.   |
| **layout** | The `grid=` lines that say where each block goes.                                                         |
| **row**    | One item of a list. The user searches the rows and picks one.                                             |
| **action** | A button that has no place in the layout. The user runs it from the ⌘K menu.                              |
| **press**  | A click, or Enter, on a card, a block or a button.                                                        |
| **pick**   | A press on a row.                                                                                         |
| **key**    | The part of a line before `=`. A key on the keyboard is a **shortcut** or a **hotkey**.                   |
| **hotkey** | A key on the keyboard that the user gives a spot or a button in Settings.                                 |

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

- A line splits at its first `=`.
- A blank line ends a block. A line `---` ends a frame.
- In a value, `\n` is a new line and `\\` is a backslash. There are no other escapes.
- An empty value is no value. Openspot never splits a value, so a URL or a time stays whole. Only a list splits at commas,
  such as `uses=screen,clipboard`.
- The first key of a block is its kind, and its value is the id of the block. For example, `switch=wifi` is a switch
  with the id `wifi`.
- The head is the block whose first key is a key of the head (see [The head](#the-head)). A block whose first key is
  neither a kind nor a key of the head is an error. Openspot skips it.
- Openspot skips a line with an unknown key.
- A thing with its own title or icon is a block of its own, such as an `option` after a `choice`.

## The header

The header says what a spot is. It is written like a frame, in comments.

```sh
#!/bin/sh
# title=Windows
# icon=macwindow
# keywords=tile, snap
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

- The header is the comment lines right under the first line. They start with `#`, `//` or `--`. It ends at the first
  other line, or after 4096 bytes.
- The keys of the spot come first. After each empty comment line comes a `button` or a `field` block.
- Openspot reads the header, and never runs a spot to learn what it is.
- If a header key is wrong, Openspot does not load that spot, and loads the others.

| Key           | Value                                                                                                                   |
| ------------- | ----------------------------------------------------------------------------------------------------------------------- |
| `title`       | The name. By default, the file name.                                                                                    |
| `icon`        | The icon, as in a block (see [Blocks](#blocks)). A path that does not start with `/` starts at the folder of the spot.  |
| `detail`      | The line under the title.                                                                                               |
| `keywords`    | More words that find the spot in the main search, split by commas, such as `keywords=coffee, cup`.                      |
| `on`          | An event that reads the spot. Write one line for each event. See [Events](#events).                                     |
| `emits`       | The events that the spot raises, split by commas. See [Events](#events).                                                |
| `offers`      | `search`: its rows show in the main search. See [Places](#places).                                                      |
| `drop`        | The files that its card takes: extensions such as `mov,mkv`, `folder`, or `*`. See [The calls](#the-calls).             |
| `preview`     | `sample`: a read with `OPENSPOT_REASON=spot.preview` prints sample data for the store.                                  |
| `view`        | A SwiftUI file beside the spot, such as `view=cups.swift`. See [Views](#views).                                         |
| `mode`        | `once` (the default), `stay` or `always`. See [Modes](#modes).                                                          |
| `uses`        | What the spot uses, split by commas: `app`, `spots`, `screen`, `clipboard`, `calendar`, `network`, `files`. See [Trust](#trust). |
| `grid.<size>` | A card made of other spots. Each word is the id of another spot. See [Cards of other spots](#cards-of-other-spots).     |
| `to`          | The spot that opens when the user presses a card of other spots. See [Cards of other spots](#cards-of-other-spots).     |

| Block         | Meaning                                                                                                     |
| ------------- | ----------------------------------------------------------------------------------------------------------- |
| `button=<id>` | A command, with its `title` and `icon`. The user can give it a hotkey.                                      |
| `field=<key>` | A setting that the user chooses, with its `title` (by default, its key) and `icon`. See [Settings](#settings). |

- A spot with a `button` in its header has no card on the grid. It gives its commands instead.

## Frames

A frame is everything that a spot shows at one time. Each frame replaces the last one, so a spot can print a new frame
to show progress, then the result.

```sh
#!/bin/sh
# title=Copy
# on=sheet.open
printf 'progress=0.5\ntitle=Copying\n---\n'
printf 'text=done\ntitle=Copied\n'
```

- Openspot draws each frame as soon as it arrives.
- The spot keeps no state between calls. Each call gets the values on stdin, and prints the whole frame again, or
  nothing.
- A frame with only a head does not change what shows. Its effects happen, such as a toast (see [The head](#the-head)).
- A read that prints no frame shows nothing. Another call that prints no frame makes Openspot read the spot once more.
- When a newer change makes a call out of date, Openspot ignores its frames.
- Print a value that comes from data with a helper, so that it never adds a line or a block: `openspot_kv`,
  `openspot_row` or `esc` in a shell, and `openspot.frame` in JavaScript. `openspot check` warns of a line with no `=`,
  and of a key twice in a block where only a list repeats.
- Openspot reads `ESC ] 9;4;1;<percent>` as `progress` and `ESC ] 9;<text>` as a toast. It removes all other escape
  codes.

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

- A spot prints blocks, and the layout places them. Openspot decides each size, gap and colour.
- A block is `<kind>=<id>`. The id names its place in the layout, the call that it sends, and the thing that moves when
  it changes. Ids must be unique in one frame. Only a `row` can have the id `search`, `form` or `value`, because stdin
  uses those keys.
- Each kind keeps its data in `value`. A kind that shows several values repeats it.

| Kind      | Shows                                                                                                          | Its own keys                                                         | Sends                  |
| --------- | -------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------- | ---------------------- |
| `text`    | Words, and a small mark: a bar from `value`, or with `max` a bar for each `value` line.                        | `value`, `max`                                                       |                        |
| `number`  | A big number, with its `title` under it. `display` shows in place of `value`.                                  | `value`, `display`                                                   |                        |
| `graph`   | One `value` from 0 to 1 is a ring in a square place and a bar in a wide one. More values are bars, newest last. | `value`, and `max` for bars                                          |                        |
| `picture` | An image that fills its place.                                                                                 | `icon`                                                               |                        |
| `view`    | The SwiftUI view that the header names (see [Views](#views)).                                                  | any key that the view reads                                          |                        |
| `switch`  | A switch, or with `type=tick` a round tick before its words, for a thing to do.                                | `value`: `true` or `false`, `type`                                   | `<id> true` or `false` |
| `field`   | A text field, or with a `type` another input.                                                                  | `value`, `type`, `placeholder`, `required`, `readonly`, `min`, `max` | `<id> <value>`         |
| `choice`  | A menu of the `option` blocks after it, a list when it covers two lines or more, or swatches of `color` lines. | `color`, `value`, `type`                                             | `<id> <option id>`     |
| `option`  | One choice of the `choice` right before it.                                                                    | `title`, `icon`                                                      |                        |
| `button`  | A button, or an action (see [Buttons and actions](#buttons-and-actions)).                                      | `shortcut`, `confirm`, `close`, `look`, `form`, `scope`              | `<id>`                 |
| `section` | A title over the blocks after it.                                                                              |                                                                      |                        |
| `repeat`  | The place of the rows (see [Rows](#rows)).                                                                     | `grid` lines                                                         |                        |
| `row`     | One item of a list (see [Rows](#rows)).                                                                        | the keys in [Rows](#rows)                                            | `open <id>`            |

- The `type` of a field: none for one line of text, `multiline` for several lines, `slider` from `min` to `max` (0 to 100
  by default), which sends a whole number when the user lets go, and `hotkey` for a shortcut that a press records.
- `type=multiple` lets a choice pick several options (see [Buttons and actions](#buttons-and-actions)).
- Each kind also takes `title`, `detail`, `tone` and `icon`. Openspot skips a key that a kind does not take.
- The value of `icon` says what it draws:
  - a path of an image file, such as `cups.png`, draws the image;
  - an `https://` URL draws an image from the web, which Openspot downloads once and keeps;
  - any other path draws the Finder icon of the file. It must contain a `/` or start with `~`, such as `./notes.txt`;
  - a name of lowercase letters, digits and dots, such as `wifi`, is an SF Symbol;
  - any other text, such as `😀`, shows as it is.
- `tone` is `good`, `warn` or `bad`. On a text, it colours the detail, or the title when there is no detail.
- `color=#RRGGBB` on a text or a number draws a thin bar of that colour at its leading edge.
- `look` is the box of a text, a number or a button: `tile` or `bare`, and on a button also `chip` or `strong`.
- `align=left`, `right` or `center` places a block that is smaller than its place.

## Layouts

The layout says where each block goes, as CSS grid areas do.

- Each `grid=` line of the head is one line of the sheet. Each word is one cell: the id of a block, `.` for an empty cell,
  or `-` for a divider across the line.
- The words of a line set the columns. A block fills the rectangle of cells that its id covers, and each id must cover a
  rectangle. A smaller block inside a larger one sits on top of it, at the edge that it touches.
- `grid.<size>=` lines are the layout of the card at one size: `small`, `wide`, `square`, `strip` or `large`. The user
  chooses the size of each card. A block that only a card layout places shows only on the card.
- A card layout can have more lines than the card has rows. A size with no layout uses the layout of the nearest smaller
  size. A spot with no card layout shows the default card (see [The main block and the card](#the-main-block-and-the-card)).
- With no `grid=` line, the sheet shows each block that is not a button in one column, in the order printed, then its
  rows. A `section` starts a new group.

## Buttons and actions

A button is a verb. If the layout places it, the sheet draws it. If not, it is an action in the ⌘K menu.

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

- An action sends `<spot> <id> <row id>` while a row is selected, and `<spot> <id>` when none is.
- `scope` says when the ⌘K menu shows an action: `scope=item`, the default, only while a row is selected, and
  `scope=spot` always.
- `close=true` closes the panel after the call. `confirm` asks for a second press.
- A button `shortcut` is a letter, a digit, `return`, `backspace` or `,`, after `cmd+`, `shift+`, both or neither, such as
  `cmd+shift+n`, or `escape` alone. A row `shortcut` is any text (see [Rows](#rows)). The user gives hotkeys in Settings
  (see [Settings](#settings)).
- An action must have a `title`. `openspot check` reports an action with no title or with a wrong shortcut.
- `shortcut=escape` presses the button instead of closing the sheet, as a Cancel button does.
- In a ⌘K menu of more than 5 rows, a field searches them, so only a `shortcut` with `cmd` runs an action there.
- Enter on a row runs the action `open`. `button=open` gives it a `title`, and `close=false` keeps the panel open after
  a pick.
- A button with `form=true` asks for values first. The call runs once with empty stdin, and prints a `title` in its head
  and one `field`, `choice` or `switch` for each value. Then the same call runs again with the values on stdin.
- A form with only one `choice` shows its options as rows under the search field. Enter or a click sends one.
- With `type=multiple`, the choice picks several options. A checkmark marks each option of a `value` line. Enter sends
  the option of its row, and `⌘⇧A` sends each option with no checkmark. The spot keeps the picks and prints the form again.
- A form can print itself again, such as with a `title` that says what is wrong. Then it stays open.

## Rows

Rows are a list that the user searches and picks from.

| Key        | Meaning                                                                                        |
| ---------- | ---------------------------------------------------------------------------------------------- |
| `row`      | The id. A pick sends `<spot> open <id>`.                                                       |
| `title`    | The first line. By default, the id.                                                            |
| `detail`   | The line under the title.                                                                      |
| `icon`     | The icon.                                                                                      |
| `parent`   | Where the row sits in its spot. The main search shows `<spot> › <parent>`.                     |
| `tone`     | A dot of its colour on the icon.                                                               |
| `value`    | `true` draws a checkmark at the end.                                                           |
| `hides`    | The id of an action that this row does not offer. Write one line for each action.              |
| `keywords` | Words that find the row and do not show, split by commas.                                      |
| `shortcut` | Any text, such as `⌃⌥K`, that shows at the end of the row.                                     |
| `type`     | `hotkey`: a pick records a new hotkey and sends `<id> <hotkey>`.                               |
| `shake`    | `true` lets a shake of the pointer be the hotkey that a pick records, as `<id> shake`.         |
| `file`     | The file that the row stands for. See [Files out](#files-out).                                 |
| `to`       | Another spot that a pick goes to, as `<spot> open <row id>` with the keys of the row on stdin. |

- Rows go into a `repeat`, or into a list when there is none.
- Openspot searches the rows itself, and puts recent picks first. `recents=false` in the head turns that off.
- With `on=sheet.text`, each change of the search text of the sheet reads the spot, and the spot prints the rows that
  match. It also reads the spot when its sheet opens, as `on=sheet.open` does. Each call gets the search text on stdin
  as `search=<text>`.
- A `repeat` has its own `grid=` lines, in which each word is the place of one row. The layout repeats down for as long
  as there are rows. Rows take the places in the order in which each word first shows.

```ini
repeat=photos
grid=a a b c
grid=a a d e
```

- A row draws its `icon`, `title`, `detail`, `tone`, `value` and `shortcut`. To show more, give the row an action, or
  draw it with a `view`.

## The head

The head is the block of a frame whose first key is one of its keys. Openspot does not draw it. It holds the layout and
the effects.

- Its layout keys: `grid=` and `grid.<size>=` lines, `main`, `title` and `detail` for the card, and `recents`.
- Its effects:
  - `toast=Saved` shows a short message at once, also when the panel is closed;
  - `link=<url>` opens the URL;
  - `progress=<0 to 1>` shows progress. With it, `title` and `detail` show only while the call runs;
  - `select=<row id>` reads the spot again with that row selected;
  - `call=<n>` and `end=<n>` mark the calls of a staying spot (see [Modes](#modes)).
- The head can come anywhere in the frame. Openspot skips and reports a second head.

## The main block and the card

One block stands for the spot on its card and in the menu bar. It is the main block.

- `main=<id>` in the head names it. With no `main=`, the main block is the only `text`, `number`, `graph`, `switch` or
  slider of the frame.
- The menu bar and a card of other spots show a main `text`, `number` or `graph`. A main `switch` shows on the card
  whether its thing is on.
- A spot has a sheet when its header has `on=sheet.open`, `on=sheet.text`, a `clock`, `offers=search`, or `mode=stay` or
  `always`. A spot with none of these, such as one with only `on=panel.open` or `on=app.front`, has no sheet, and its
  rows never show.
- With no `grid.<size>=` lines, a spot shows the default card: its icon, title and detail, and an arrow when it has a
  sheet.
- When a frame is only one `switch` or one slider, the card draws that block, and a press of the card changes it.
- A press on a part of the card that is not a control opens the sheet, or sends `<spot> open` when there is no sheet.

## Events

An event makes Openspot read a spot. The header lists the events on which a read is safe.

```sh
#!/bin/sh
# title=Notes
# on=sheet.open
# on=app.front com\.apple\.Notes
```

- An event is a word `<noun>.<verb>`. It can carry a value. The table below gives the value of each event that Openspot
  raises, and `openspot event emit` gives the value of any other event.
- Each `on=` line names one event. Text after a space is a filter: a regular expression that the value of the event must
  match.
- Only an event with a value takes a filter: `search.text`, `app.front`, `app.update`, or an event that a spot emits. A
  filter on any other event is an error. `sheet.text` takes no filter either, because the spot answers every search of
  its sheet.
- Openspot never reads a spot with no event. A press of its card sends `<spot> open`.
- Each read gets the event in `OPENSPOT_REASON` and its value in `OPENSPOT_VALUE`.

| Event              | When Openspot raises it                                                      | Value         |
| ------------------ | ---------------------------------------------------------------------------- | ------------- |
| `sheet.open`       | When the sheet of the spot opens.                                            |               |
| `panel.open`       | Each time the panel opens, and once when the app starts.                     |               |
| `clock.<seconds>`  | Every that many seconds while the spot is wanted, and when the Mac wakes.    |               |
| `search.text`      | At each change of the text of the main search.                               | the text      |
| `sheet.text`       | At each change of the search text of its sheet, and when the sheet opens.    | the text      |
| `clipboard.change` | When the clipboard changes.                                                  |               |
| `app.front`        | When another app comes to the front.                                         | its bundle ID |
| `app.update`       | When Openspot has downloaded an update.                                      | its version   |
| `screen.wake`      | When the screen wakes.                                                       |               |

- Openspot also reads a spot for these reasons, which are not events:
  - `spot.change`: after a call that printed no frame;
  - `spot.want`: when a spot becomes wanted and no event has read it yet;
  - `spot.preview`: for the preview in the store.
- `openspot event emit <event> [value]` raises an event in Openspot, from a spot or a terminal. If Openspot is not
  running, it starts first.
- A spot must list each event that it raises in `emits`, such as `emits=music.track`. `openspot check` reports an `on`
  event that Openspot does not raise and that no spot emits.
- A read must not raise the event that caused it. `openspot check` warns of a spot whose `on` and `emits` share an event.
- A spot is wanted while its sheet, the menu bar or a card of other spots shows it, and while the open panel reads it at
  `panel.open`.
- A `clock` and the events other than `sheet.open`, `sheet.text` and `search.text` read a spot only while it is wanted.
  `app.update` reads each spot that lists it, wanted or not.
- A read must be safe at each event that its header lists. Only you can make sure of this. A spot has one read at a
  time.

## The calls

A call asks a spot to do one thing. It works like a CGI call: arguments, variables and stdin in, a frame out.

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

| Call                               | When                                                   |
| ---------------------------------- | ------------------------------------------------------ |
| `<spot> read`                      | An event that its header lists.                        |
| `<spot> open [row id]`             | A pick of a row, or a press of a card with no sheet.   |
| `<spot> <id> [row id] [value]`     | A change or a press of a block.                        |
| `<spot> drop <path> [path]...`     | A drop of files on its card.                           |
| `<spot> drag <row id> [row id]...` | A drag of rows that stand for files out of its sheet.  |
| `<spot> <command>`                 | A press of the hotkey that the user gave a command.    |

- `read` is the only reserved call. `open`, `drop` and `drag` are default ids. A block must not use them, but a button can
  use `open`.
- A new default id reaches only a spot that asks for it.
- A drop on a card waits for the running call of the card. A drop on a card with rows opens its sheet, and the frame can
  select the new row with `select=`.
- The hotkeys of one spot run one at a time, in order, and never stop a call. Only the user gives a command a hotkey.

Each call has three parts:

- **Arguments:** the id, its row, then its values, so that `case "$1"` handles each call. A value over 64 KB goes only
  on stdin.
- **Variables:** `OPENSPOT_REASON` and `OPENSPOT_VALUE` of a read, `OPENSPOT_ID`, the id of the spot, `OPENSPOT_DATA`,
  a folder for its files that one spot folder shares, `OPENSPOT_SH`, the shell helper, and `PATH`, with the `openspot`
  command first.
- **Stdin:** one block of what the user filled in and typed: a line for each field of the sheet, `search=` with the
  search text, and a `form=` line for each other text that the user may have meant, such as the same keys in another
  keyboard layout. A value that is not a field comes as `value=`.

```ini
title=Groceries
search=milk
form=ьшдл
```

The shell helper writes values for you:

| Function                                    | Does                                                                                                |
| ------------------------------------------- | --------------------------------------------------------------------------------------------------- |
| `esc <text>`                                | Prints text as a value.                                                                             |
| `value <key>`                               | Prints each value of the key from stdin, one per line, in order.                                    |
| `openspot_kv <key> <value>`                 | Prints one line, with its value escaped.                                                            |
| `openspot_row <id> <title> [detail] [icon]` | Prints one row.                                                                                     |
| `openspot_rows [kind]`                      | Prints a row, or a block of that kind, for each tab-split line of stdin: id, title, detail, icon.   |
| `openspot_serve <function> "$@"`            | Runs the function with the three parts of each call, in each mode.                                  |

- Loading the helper reads all of stdin, except in a staying spot.

```sh
#!/bin/sh
. "$OPENSPOT_SH"
printf 'field=output\n'
openspot_kv value "$(value input)"
```

## The life of a call

A call starts, prints, and ends. These rules say how long it can take, and what a stop does.

- A `read` has 10 seconds to print its first frame or end. Other calls have no time limit.
- A new value of a block stops the older call of that block. A second press of a running call stops it: its process
  group gets the terminate signal, then the kill signal. When Openspot quits, it stops each call.
- A call ends when its output closes. A stopped call changes nothing.
- Exit code 0 is success. Any other code is a failure, and the user sees the last line of stderr. A failure can print
  `link=<url>`, the place that fixes it.
- A failed read at `panel.open` only marks its card, and goes to the app log.
- A stop can come at any time, and two calls can run at once. A spot must never leave a file half written.

## Places

The user decides where a spot shows. A spot only offers.

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

- The user gives each spot its hotkey, puts spots in the menu bar, floats them, and orders and sizes the cards. A spot
  must not claim a hotkey or a place.
- `offers=search` shows the rows of the spot in the main search. It needs `on=panel.open` or a `clock`. Openspot ranks
  the rows by the picks of the user.
- The user can give any spot with a sheet a hotkey, or a shake of the pointer, in Settings. It shows the spot in a small
  window at the pointer, which stays while the user works in other apps. The spot never learns where it shows.
- `on=search.text <pattern>` makes a spot answer the main search. Openspot reads it at each change of a text that the
  pattern matches, with no pause. A newer text stops the older call. The answer should be fast.
- Its rows show first in the main search until the newest text has an answer, and go at once when the pattern no longer
  matches. A pick of a row sends `<spot> open <row id>`.
- A spot whose only event is `search.text` has no card.
- An answer can be one card instead of rows: its head has `grid.large=` or `grid.strip=` lines, and its main block has a
  `value`. A pick of the card sends `<spot> open <value>`.
- `openspot calc solve <words>...` prints the answer of a sum, a conversion or a date as a row.
- A spot with a `clock`, another event, or `mode=stay` or `always`, and a main `text`, `number` or `graph`, can show in
  the menu bar when the user puts it there. A read that prints nothing hides it until the next read.
- A spot with a `clock` has no card on the grid until the user shows it.

## Modes

Openspot starts a spot for each call, unless its header says otherwise.

- `mode=once` starts a process for each call.
- `mode=stay` keeps one process that gets each call on stdin while the spot is wanted.
- `mode=always` keeps that process from the start of Openspot until it quits.
- A `.js` file with a header and no execute permission runs inside Openspot. A `.js` file with no header can hold shared
  code. An executable `.js` file runs as a process, like any other spot.

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

- The file defines `main(args, env, input)`, which gets the three parts of a call and returns the text of a frame.
- `openspot.call(["calc", "solve", "2+2"])` runs the `openspot` command and returns `{ stdout, code }`. A second argument
  gives its stdin.
- `openspot.frame(object)` writes an object, or a list of objects, as blocks.
- It has no files, no network and no process of its own. It runs one call at a time, on a thread of its own.
- Openspot waits 2 ms for its frame in the same turn as the keystroke, and shows a later frame in the next turn.
- A call has 10 seconds. After that it fails as a slow read, and the spot answers its next call.

### A staying spot

```sh
#!/bin/sh
# title=Relay
# mode=always
# on=panel.open
. "$OPENSPOT_SH"
main() {
  case "$1" in
    read) printf 'field=message\ntitle=Message\n\nbutton=send\ntitle=Send\nshortcut=cmd+return\n' ;;
    send) openspot_kv toast "Sent: $(value message)" ;;
  esac
}
openspot_serve main "$@"
```

Openspot writes each call to its stdin as one block, then a blank line. `call=<n>` numbers the call, an `arg` line gives
each argument, an `env.<name>` line gives each variable, such as `env.OPENSPOT_REASON` of a read, and one `input` line
holds its stdin.

```ini
call=4
arg=send
input=message=Hello\n
```

- A staying spot is one process that talks both ways over stdin and stdout. Each call goes to the running process, and
  no call starts a second copy.
- `openspot_serve main "$@"` runs `main` with the three parts of each call, and prints `call=<n>` before its output and
  `end=<n>` after it. The same `main` works in each mode.
- The spot can print frames at any time. It must end each call with `end=<n>` in a head. A frame of only `call=<n>`
  starts the output of that call.
- A second press sends the block `stop=<n>`. A newer search text sends `stop=<n>` for the read of the older text, so only
  the answer to the newest text shows. A read after the first gets `stop=<n>` after 10 seconds, and fails as a slow read.
- With `mode=stay`, the process runs while the spot is wanted, or while a call waits for its `end`. When the spot is no
  longer wanted, Openspot closes its stdin, and the spot must end, with each process that it started. After 2 seconds
  its process group gets the terminate signal, and 2 seconds later the kill signal.
- After 3 failures in one minute, Openspot tells the user, and starts the spot again only when its file changes. Keep
  what must survive in `OPENSPOT_DATA`.

### A Swift script

- A Swift file with `#!/usr/bin/env swift` on its first line is a spot, with its header in `//` lines.
- It needs the Command Line Tools. Openspot builds it once, and again when the file changes.

## Views

A view draws what blocks cannot: a SwiftUI view in the place of a block.

```sh
#!/bin/sh
# title=Cups today
# on=panel.open
# on=sheet.open
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

- `view=<file>` in the header names a SwiftUI file beside the spot. A `view=<id>` block draws it in its place.
- The spot and its view must be in a folder of their own, such as `cups/cups.sh` and `cups/cups.swift`.
- The file declares `struct SpotView: View` with `let spot: SpotInput`, and has no top-level code.

| Member            | Gives                                                             |
| ----------------- | ----------------------------------------------------------------- |
| `spot["key"]`     | The last value of a key of its block, or nil.                     |
| `spot.all("key")` | Each value of a key that repeats.                                 |
| `spot.size`       | The size of its place.                                            |
| `spot.inset`      | The space that other cards keep between their edge and the words. |
| `spot.corner`     | The corner radius of the card.                                    |
| `spot.ink`        | The colour of words, for light and dark.                          |
| `spot.secondary`  | The opacity of a second line.                                     |
| `spot.accent`     | The accent colour.                                                |
| `spot.font`       | The fonts of the cards: `title`, `detail`, `metric` and `value`.  |

- The view fills its place, and the whole card when there is no card layout. It cannot change the size of its place.
- It gets the keys of its block in each frame. A new frame keeps its `@State`.
- The view only draws. A press works as on any card.
- Openspot compiles it when its card first shows, and again when the file changes. A view that does not compile shows
  its first error, and `openspot check` prints it.
- A shared spot carries the compiled view as `<name>.view`, which Openspot uses instead of the source.
- The view runs inside Openspot, so a crash quits Openspot. Do the work in the spot, and only draw in `body`.

## Cards of other spots

One card can show several spots side by side, such as the battery, the CPU and the memory. You write only a header, and
Openspot fills the card with the main blocks of the spots that it names.

```sh
#!/bin/sh
# title=System
# grid.large=battery battery cpu    cpu
# grid.large=battery battery memory memory
# to=system-info
```

- Each `grid.<size>=` line is one line of the card at that size, as in [Layouts](#layouts). Here each word is the id of
  another spot, not of a block. That spot's main block fills the cells that its id covers.
- `to=` names the spot that opens when the user presses the card. In the example, a press opens the spot
  `system-info`. With no `to=`, a press does nothing.
- While the card shows, Openspot reads each spot that it names, at the events of that spot. A spot with no event that
  reads it, such as one with only `on=sheet.open`, gets a read with `spot.want`. Each named spot must have an `on=`
  event.
- A good spot to name has a `clock` and a main `text`, `number` or `graph`.
- Openspot looks for each id in the folder of the card first, then among all spots.
- Each line of one size must have the same number of words, and each id must cover a rectangle. All lines must use one
  size.
- The header takes only `title`, `icon`, `detail`, `keywords` and `to` besides its `grid.<size>=` lines. Openspot does
  not load a card with any other key, because the card runs no code.

## Files out

A row can stand for a file that the user drags into another app.

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

- A row with `file=<path>` stands for that file. The user can drag it into any app that takes files. The path must start
  with `/`.
- The other app copies or moves the file. A read should leave out each file that no longer exists.
- When a drag ends in another app, Openspot sends `<spot> drag <row id>...`. A drag with no drop sends nothing. If the
  call prints no frame, Openspot reads the spot again.
- A drag of the icon in the head of the sheet drags each row that has a `file`.

## The openspot command

A spot asks the Mac and Openspot for things through one command, which works the same in a terminal.

- Each capability is `openspot <noun> <verb>`.
- A noun names its commands, its events and its use, such as `openspot clipboard copy`, `clipboard.change` and
  `uses=clipboard`.
- A call that reads files or asks the Mac gives the same answer whether Openspot runs or not. A call that needs the
  running app starts it, and waits up to 10 seconds.
- Ctrl-C stops a call, and the stopped work changes nothing.
- `openspot help` lists each capability. `openspot help <noun>` prints the guide of a noun, such as `screen` or
  `calendar`.
- A capability that cannot answer prints `status=<word>`. A capability that keeps state keeps it in its own helper.
- When macOS already has a command, such as `open`, use it. For the screen and the clipboard, use `openspot screen` and
  `openspot clipboard`, so that the user sees each use.
- These calls fail in a read, so that a read changes nothing and opens nothing:
  - calls that wait for the user: `color pick` and `folder pick`;
  - calls that capture the screen: `screen shot`, `screen record start` and `screen record stop`;
  - calls that change the Mac or the user's data: `window move`, `clipboard copy`, `clipboard paste`, `calendar add`,
    `reminders add`, `reminders done`, `spot add` and `spot remove`;
  - calls that change Openspot or its places: `app quit`, `update install`, and `setting set` of a key that Openspot
    keeps for the user (see [Settings](#settings));
  - calls that open a window or the panel: `spot show`, `spot open`, `spot review`, `spot store`, `setting change`,
    `update check`, `calendar show` and `reminders show`.
- `calendar add --dry-run` and `reminders add --dry-run` change nothing, so they work in a read.
- `openspot batch` runs one call for each line of stdin, and prints `---` after each. It stops at the first failure.
- `--frame` makes `app status`, `spot list` and `setting list` print blocks instead of JSON.

The commands that try a spot are in [Try your spot](#try-your-spot). The others:

| Command                                            | Does                                                                                              |
| -------------------------------------------------- | ------------------------------------------------------------------------------------------------- |
| `openspot guide`                                   | Prints this page.                                                                                 |
| `openspot spot show <id>`                          | Opens the panel with the spot selected.                                                           |
| `openspot spot add <git url, folder or file.spot>` | Adds a spot, and records it in `spots.lock`. An update that needs a new use also needs `--yes`.   |
| `openspot spot remove <id>`                        | Moves a spot that `spot add` added to the Trash.                                                  |
| `openspot spot stats`                              | Prints what each spot cost and used. See [Stats](#stats).                                         |

### Settings

A setting is a choice of the user that a spot keeps.

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

- A `field` block in the header names a setting. The Settings spot lists it, set or not.
- Enter on it runs the action with the same id, which can answer with a form. `⌘⌫` removes the value.
- `openspot setting get <key>` prints the value, or nothing. `openspot setting set <key> [value]` keeps the value, or
  removes it when there is no value. In a terminal, `--spot <id>` names the spot.
- Keep a choice of the user in a setting. Keep what the spot makes, such as a cache, in `OPENSPOT_DATA`.
- Openspot keeps some keys for the user, and a `field` must not use them:
  - of any spot: `enabled` and `menubar`, `true` or `false`, and `float` and `key.<command>`, a hotkey such as
    `ctrl+option+k` or `shake`, or no value to remove it;
  - of the spot `openspot`, which is the app: `login`, `link` and `careful`, `true` or `false`, and `panel-key` and
    `fix-key`.
- Each of these keys needs the use of the call that does the work (see [Trust](#trust)).

### Stats

Openspot counts what each spot cost and used, so that the user can see it.

```sh
openspot spot stats --days 7 --frame
```

- Openspot keeps one file for each day, for 90 days. The numbers of today are live.
- `--days N` adds up the last N days. `--spot <id>` shows one spot.
- `--frame` prints a `row=<id>` block for each spot, the most CPU first, then a `use=<n>` block for each call that needs
  a use, the newest first.

| Row key              | Meaning                                                               |
| -------------------- | --------------------------------------------------------------------- |
| `title`, `detail`    | The name of the spot, and its numbers in words.                       |
| `runs`, `failures`   | The calls that ended, and those that failed.                          |
| `cpu`, `seconds`     | The CPU seconds of its processes, and the wall time of its calls.     |
| `read`, `written`    | The bytes that its processes read and wrote.                          |
| `wakeups`            | The times its processes woke the CPU.                                 |
| `call.<noun>.<verb>` | The count of one call that needs a use, such as `call.screen.shot=2`. |
| `network`            | `declared` when its header names `network`.                           |
| `fault`, `tone`      | Its last error, with `tone=bad`.                                      |

- A `use` block holds `time`, `spot`, `call`, such as `app.quit`, and `declared`, `true` or `false`.

## Trust

A spot runs with the rights of the user. Openspot shows what a spot can do, and what it did.

```sh
#!/bin/sh
# title=Coffee
# uses=app
openspot app quit
```

- Openspot asks nothing in daily use. It shows what a spot can do when the user adds or updates it, and shows each use
  after it happens.
- Openspot knows which spot makes each call of `openspot` from its own records, not from the variables of the process.
  Only the processes of the user can reach the API.
- `uses` names what a spot uses. Openspot does not load a spot with an unknown use.

| Use         | The calls that need it                                                                                                                                          |
| ----------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `app`       | `app quit`, `update check`, `update install`, and `setting set` of `menubar`, `float`, `key.<command>` or of the spot `openspot`                                |
| `spots`     | `spot add`, `spot remove`, `spot new`, `spot run`, `spot log`, `setting list`, `setting set` of `enabled`, and `setting get`, `set` or `change` of another spot |
| `screen`    | `screen sources`, `screen shot`, `screen record`, `window frame`, `window move` and `color pick`                                                                |
| `clipboard` | `clipboard copy`, `clipboard paste` and `clipboard read`                                                                                                        |
| `calendar`  | each call of `calendar` and `reminders`                                                                                                                         |
| `network`   | No call. The spot reaches the network.                                                                                                                          |
| `files`     | No call. The spot writes outside its data folder.                                                                                                               |

- A call that needs a use that the header does not name still runs, and shows one toast for each spot, use and day.
  `openspot check` cannot report it, because only a run shows it.
- Before an add, the review shows the title, the `uses`, and a line `Can also` with what the code seems to do but does
  not name: the network, `rm`, `screencapture`, `pbcopy` or `pbpaste`. It warns, and never blocks the add.
- An update with no new use applies quietly. An update with a new use waits for `--yes`.
- Careful mode is a setting of the user, off by default. It runs each process of a spot in a sandbox: no network unless
  `uses=network`, and writes only to its data folder and the temp folders unless `uses=files`. With `uses=screen`, it
  can also write to the Desktop, Movies and the screenshots folder. In Careful mode, a call that needs a use that the
  header does not name fails.
- Without Careful mode, the data folder is no boundary.

## Messages

A toast or a failure line says what happened, and why when you know it. It says what still worked, and the exact step
that fixes the rest. Use plain words, a calm tone, and one or two short sentences. Put each key in backticks.

| Instead of                    | Write                                                                                  |
| ----------------------------- | -------------------------------------------------------------------------------------- |
| `Oops! Something went wrong.` | `Openspot cannot find a screenshot.`                                                   |
| `Error 1: osascript failed.`  | ``Copied, but Openspot cannot paste. Press `⌘V`, or allow Openspot in Accessibility.`` |

## Versions

The version at the top is the version of this page. A new word raises the minor number, such as `1.1`. A draft becomes
`final` when real use proves it, and a final version never changes the meaning of a word. A change that breaks an old
spot raises the major number, and adds a header key `protocol=<major>`. A spot with no such key is version 1.

## How to extend

An old spot never sees a word that it did not ask for, and an old app skips a word that it does not know.

| To add               | Add                                                               |
| -------------------- | ----------------------------------------------------------------- |
| A thing that happens | an event `<noun>.<verb>`                                          |
| A thing to draw      | a kind `<kind>=`, which an old app skips and reports              |
| A detail of a kind   | a key, or a `type` value                                          |
| A power of the Mac   | a noun: `openspot <noun> <verb>`, its events and its `uses` word  |
| A complex look       | nothing: a `view` of the spot                                     |
