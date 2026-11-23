# Openspot protocol

`1.1` `draft`

This is the contract between a spot and Openspot: what a spot prints, which calls it gets, and what it can ask. To learn
by example, start with the [guide](GUIDE.md).

## A spot

Openspot shows spots in three places: the **panel**, the window that the Openspot hotkey opens, with the main search and
a grid of **cards**; the **card** of each spot on that grid; and the **sheet**, the view of one spot that opens over the
panel.

A spot is a script. Openspot runs it, and the spot prints what to show:

```text
event   ─ on= ─►  <spot> read           Openspot runs the spot
spot    ─ prints ─►  blocks             Openspot draws them
press   ─ on a block ─►  <spot> <id>    the user or an agent acts
```

- A spot lives in a **spot folder**: a folder `<name>.spot` in the spots folder, such as `coffee.spot/coffee.sh`. The
  folder holds its scripts, its `readme.md`, its `sample.sh` and any file that they need.
- `sample.sh` prints what the spot would show, with made-up data, so that the store can show the spot before you add it.
  A click on that sample runs nothing. Publish runs it once and ships what it printed as `sample.frame`, a frame like any other, which is all a
  shared spot shows before you add it. `sample.sh` is a spot of its own only in `sample.spot`.
- A line of `readme.md` that holds only a Markdown image shows a picture or a video from the folder: PNG, JPEG, MOV or
  MP4. A picture can also be an `https` address, which Openspot fetches once, with no cookies. A video at an `https`
  address shows as a link that opens in your browser.

```text
![The sheet](shot.png)
```

- The id of a script is the name of its folder, such as `coffee`. A script with another name adds it, such as
  `home/lights` for `home.spot/lights.sh`.
- The folder is shared as one unit of at most 25 MB, and its scripts share one data folder. A file in it that isn't
  executable can hold shared code.
- Openspot moves a loose script into a spot folder of its name, with the files of the same name, such as `coffee.md`,
  which becomes `readme.md`.
- A spot only says what it has. The user decides where it shows and which key opens it.
- An agent can do anything the user does, with `openspot spot run <id> <call>` and `openspot event emit`. A spot
  can't tell who called it.

## The keys of a spot

Every spot answers the same keys, so a person learns them once. Openspot gives each key its act, and a spot only says
what it has.

| Key          | What it does                                                                                              |
| ------------ | --------------------------------------------------------------------------------------------------------- |
| Return       | The main act of the spot: it runs the spot, or opens its rows when the rows are what the spot is for.     |
| `⌘` Return   | Opens the spot's [Settings](#settings): Show in the menu bar and each `field`.                            |
| `⌘Y`         | Opens the rows of a spot whose Return runs its command, as its **History**.                               |
| `⌘K`         | Opens the menu of all acts, when it holds more than the footer shows.                                     |

- A spot with one `button` in its header and its own rows, such as Dictate, runs that command on Return. Its rows are
  its History, on `⌘Y` and in its ⌘K menu. With no key yet, Return records one first.
- A spot whose rows are its main use, such as a clipboard history, has no `button`: Return opens its rows.
- The ⌘K menu of a card starts with the acts that Openspot adds, always in this order: first what the user does with the
  spot, the main act on Return, History and Share; then what changes it, Settings, Edit and Change Icon; then Turn off
  or a red Delete. The acts that spots offer to every card with `offers=actions` follow, under the name of their spot. A
  spot adds no act to its own card. Its sheet carries what it does.
- A card's `⌘` keys work while a search is typed, except the ones that edit the words, such as `⌘⌫`.
- Edit copies a prompt that sends an agent to the spot's file. A person changes a spot there, not in its Settings.
- A choice that stays, such as a look or a folder, is a `field` in Settings, not a part of the spot's own sheet.
- A card shows an arrow only when Return opens another view of the spot, its sheet. A card that Return runs, as an app
  runs, shows no arrow and no Run.
- The footer names the spot's own keys first and `⌘K Actions` last.

## The format

Everything a spot prints, and its header, is lines of `key=value`.

```ini
text=title
title=Wi-Fi
detail=Home · 82 Mb/s

switch=wifi
value=true
---
```

- A line splits at its first `=`. The part before it is the key.
- A blank line ends a block. A line `---` ends a frame (see [Frames](#frames)).
- In a value, `\n` is a new line and `\\` is a backslash. There are no other escapes.
- An empty value is no value. Openspot never splits a value, so a URL or a time stays whole. Only a list splits at
  commas, such as `uses=screen,clipboard`.
- The first key of a block is its kind, and its value is the block's id. `switch=wifi` is a switch with the id `wifi`.
- The head is the block that starts with a key of the head (see [The head](#the-head)). A block that starts with any
  other unknown key is an error, and Openspot skips it.
- In a frame, Openspot skips a line with an unknown key, and `openspot check` reports it. In the header, an unknown
  key is a fault (see [The header](#the-header)).
- Anything with its own title or icon is a block of its own, such as an `option` after a `choice`.

## The header

The header says what a spot is. Openspot reads it without running the spot.

- The header is the comment lines right after the first line. They start with `#`, `//` or `--`. It ends at the first
  other line. A header over 64 KB is a fault, and Openspot doesn't load that spot.
- The keys of the spot come first. After each empty comment line comes a `button` or a `field` block.
- If a header key is wrong, or is one that Openspot doesn't know, such as `titel`, Openspot doesn't load that spot.
  Other spots still load.

| Key           | Value                                                                                                                            |
| ------------- | -------------------------------------------------------------------------------------------------------------------------------- |
| `title`       | The name. By default, the file name.                                                                                             |
| `icon`        | The icon, as in a block (see [Blocks](#blocks)). A path that doesn't start with `/` starts at the spot's folder.                 |
| `detail`      | The line under the title.                                                                                                        |
| `keywords`    | More words that find the spot in the main search, split by commas, such as `keywords=coffee, cup`.                               |
| `placeholder` | The text the spot takes in a [slash command](#slash-commands), such as `placeholder=Text to translate`. It lists the spot there. |
| `on`          | An event that makes Openspot ask the spot what to show. One line for each event. See [Events](#events).                          |
| `emits`       | The events the spot raises, split by commas. See [Events](#events).                                                              |
| `offers`      | A place where the spot can show: `card`, `search`, `menubar`, `float` or `window`. One line each. See [Places](#places).         |
| `drop`        | The files its card takes: extensions such as `mov,mkv`, `folder`, or `*`. See [The calls](#the-calls).                           |
| `edits`       | `spots`: its sheet is also the Edit sheet of each spot. `keys`: its sheet, on the page `spot:<id>`, sets the keys of each spot. Only a spot of the app takes it. |
| `view`        | A SwiftUI file next to the spot, such as `view=cups.swift`. See [Views](#views).                                                 |
| `source`      | A Swift file, or a folder of Swift files, that a Swift spot is built with. One line each. See [A Swift spot](#a-swift-spot).     |
| `mode`        | `once` (the default), `stay` or `always`. See [Modes](#modes).                                                                   |
| `press`       | `open`: a press of the card sends `<spot> open` though the spot has a sheet, which **Open** in ⌘K opens. `sheet` is the default. |
| `uses`        | What the spot uses, split by commas: `app`, `spots`, `screen`, `clipboard`, `calendar`, `network`, `files`. See [Trust](#trust). |
| `grid.<size>` | A card made of other spots. Each word is a spot id. See [Cards of other spots](#cards-of-other-spots).                           |
| `to`          | The spot that opens when the user presses a card of other spots. See [Cards of other spots](#cards-of-other-spots).              |

| Block         | Meaning                                                                                                                                                                                                                                                                      |
| ------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `button=<id>` | A command, with its `title` and `icon`. The user can give it a hotkey. `confirm` asks for a second press. `close=false` keeps the panel open after a [slash command](#slash-commands) that shows nothing, and `placeholder` lists it there, as the grey hint after its name. |
| `field=<key>` | A setting the user chooses, with its `title` (by default, its key) and `icon`. See [Settings](#settings).                                                                                                                                                                    |

- A spot with a `button` in its header has no card. It gives its commands instead.
- Return on a spot with one `button` and no `on=` events runs it, as its hotkey does. When it has no hotkey yet, Return
  opens its Keys, the sheet of Keys… in its ⌘K menu, and records one.
- A spot with one `button` and its own rows runs the command on Return, and its rows open as its History on `⌘Y`. A
  spot with more `button`s runs them by their hotkeys and from its ⌘K menu. See [The keys of a spot](#the-keys-of-a-spot).
- `confirm=<words>` on a header `button` makes a press of its card, or its row in the ⌘K menu, ask twice: the first
  press shows the words, and the second runs the command. Its hotkey doesn't run it at once: it shows the panel on the
  spot with the words, and Return, or the hotkey again, runs it.

```sh
#!/bin/sh
# title=Empty Trash
#
# button=empty
# title=Empty Trash
# confirm=Press again to empty the Trash
case "$1" in empty) echo 'toast=Emptied' ;; esac
```

## Frames

A frame is everything a spot shows at one time. Each new frame replaces the last one, so a spot can show progress and
then the result.

```text
 what the spot prints              what it is
┌──────────────────────────────┐
│ grid=title                   │ ─┐
│ grid=wifi                    │  ├─ the head: layout and effects, not drawn
│ toast=Saved                  │ ─┘
│                              │
│ text=title                   │ ─┐
│ title=Wi-Fi                  │  │
│                              │  ├─ blocks: each one is drawn
│ switch=wifi                  │  │
│ value=true                   │ ─┘
│ ---                          │ ─── the end of this frame; the next one replaces it
└──────────────────────────────┘
```

```sh
#!/bin/sh
# title=Copy
# on=sheet.open
printf 'progress=0.5\ntitle=Copying\n---\n'
printf 'text=done\ntitle=Copied\n'
```

- Openspot draws each frame as soon as it arrives.
- A spot keeps no state between calls. Each call gets the values on stdin, and prints the whole frame again, or nothing.
- A frame with only a head doesn't change what shows, but its effects happen, such as a toast (see [The head](#the-head)).
- If a read prints nothing, the spot shows nothing. If another call prints nothing, Openspot asks the spot again.
- When a newer change makes a call out of date, Openspot ignores what it prints.
- Print a value that comes from data with a helper, so that it can't add a line or a block: `openspot_kv`,
  `openspot_row` or `esc` in a shell, and `openspot.frame` in JavaScript. `openspot check` warns of a line with no `=`,
  of a key that shows twice in a block where only a list repeats, and of a key that the head or a kind doesn't take. A
  row can hold keys of its own, which Openspot skips.
- Openspot reads `ESC ] 9;4;1;<percent>` as `progress` and `ESC ] 9;<text>` as a toast, and removes other escape codes.
- A read that prints the same frame as the one that shows, with only a head and rows, changes nothing, so Openspot skips
  it. Its toast still shows. A frame with another block, or over 256 KB, is drawn again.

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

- A spot prints blocks, and the layout places them. Openspot picks every size, gap and colour.
- A block is `<kind>=<id>`. The id names its place in the layout, the call it sends, and what moves when it changes.
  Ids must be unique in one frame. Only a `row` can use the id `search`, `form` or `value`, because stdin uses them.
- Each kind keeps its data in `value`. A kind that shows several values repeats it.

| Kind      | Shows                                                                                                           | Its own keys                                                         | Sends                  |
| --------- | --------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------- | ---------------------- |
| `text`    | Words, and a small mark: a bar from `value`, or with `max` a bar for each `value` line.                         | `value`, `max`                                                       |                        |
| `number`  | A big number, with its `title` under it. `display` shows instead of `value`, and its `unit` part draws faint.   | `value`, `display`, `unit`                                           |                        |
| `graph`   | One `value` from 0 to 1 is a ring in a square place and a bar in a wide one. More values are bars, newest last. | `value`, and `max` for bars                                          |                        |
| `picture` | An image that fills its place.                                                                                  | `icon`                                                               |                        |
| `view`    | The SwiftUI view the header names (see [Views](#views)).                                                        | any key the view reads                                               |                        |
| `switch`  | A switch, or with `type=tick` a round tick before its words, for a thing to do.                                 | `value`: `true` or `false`, `type`                                   | `<id> true` or `false` |
| `field`   | A text field, or another input with a `type`.                                                                   | `value`, `type`, `placeholder`, `required`, `readonly`, `min`, `max` | `<id> <value>`         |
| `choice`  | A menu of the `option` blocks after it, a list when it covers two lines or more, or swatches of `color` lines.  | `color`, `value`, `type`                                             | `<id> <option id>`     |
| `option`  | One option of the `choice` right before it.                                                                     | `title`, `icon`                                                      |                        |
| `button`  | A button, or an action (see [Buttons and actions](#buttons-and-actions)).                                       | `shortcut`, `confirm`, `close`, `look`, `form`, `scope`              | `<id>`                 |
| `section` | A title over the blocks after it.                                                                               |                                                                      |                        |
| `repeat`  | The place of the rows (see [Rows](#rows)).                                                                      | `grid` lines                                                         |                        |
| `row`     | One item of a list (see [Rows](#rows)).                                                                         | the keys in [Rows](#rows)                                            | `open <id>`            |

- A field's `type`: none for one line of text, `multiline` for several lines, `slider` from `min` to `max` (0 to 100 by
  default), which sends a whole number when the user lets go, and `hotkey` for a hotkey that a press records.
- `type=multiple` lets a choice pick several options (see [Buttons and actions](#buttons-and-actions)).
- Every kind also takes `title`, `detail`, `tone` and `icon`. Openspot skips a key that a kind doesn't take.
- A `text` that covers two lines or more shows its `detail` under its `title`, on as many lines as the place holds.
- `icon` draws according to its value:
  - a path of an image file, such as `cups.png`, draws the image;
  - an `https://` URL draws an image from the web, which Openspot downloads once and keeps;
  - any other path draws the Finder icon of the file. It must contain a `/` or start with `~`, such as `./notes.txt`;
  - a name of lowercase letters, digits and dots, such as `wifi`, is an SF Symbol;
  - any other text, such as `😀`, shows as it is.
- `tone` is `good`, `warn` or `bad`. On a text, it colours the detail, or the title when there's no detail.
- `color=#RRGGBB` on a text or a number draws a thin bar of that colour at its leading edge.
- `look` is the box of a text, a number or a button: `tile` or `bare`, and on a button also `chip` or `strong`.
- `align=left`, `right` or `center` places a block that is smaller than its place.

## Layouts

A layout says where each block goes, the way CSS grid areas do.

```text
grid=title title title      ┌──────────────────────────────┐
grid=wifi  wifi  nets       │ title                        │
grid=all   .     nets       ├───────────────────┬──────────┤
grid=-     -     -          │ wifi              │          │
grid=note  note  note       ├─────────┬─────────┤   nets   │
                            │ all     │  empty  │          │
                            │ ─────────────────────────────│  the divider
                            │ note                         │
                            └──────────────────────────────┘
```

Three words make three columns. `nets` covers the last column of two lines, `.` leaves a cell empty, and `-` draws a
divider across its line.

- Each `grid=` line of the head is one line of the sheet. Each word is one cell: the id of a block, `.` for an empty
  cell, or `-` for a divider across the line.
- The words of a line set the columns. A block fills the rectangle of cells that its id covers, and each id must cover a
  rectangle. A smaller block inside a bigger one sits on top of it, at the edge it touches.
- A `view`, a list, a chart, an image or a `multiline` field takes the free height of the sheet. `grow=false` keeps it
  at the height of its grid lines, and the sheet is as tall as its lines.
- `grid.<size>=` lines lay out the card at one size: `small`, `wide`, `square`, `strip` or `large`. The user chooses the
  size of each card. A block that only a card layout places shows only on the card.
- A card layout can have more lines than the card has room for. A size with no layout uses the layout of the next
  smaller size. A spot with no card layout shows the default card (see
  [The main block and the card](#the-main-block-and-the-card)).
- With no `grid=` line, the sheet shows each block that isn't a button in one column, in the order printed, then the
  rows. A `section` starts a new group.

## Buttons and actions

A button is a verb. If the layout places it, the sheet draws it. If not, it's an **action** in the ⌘K menu. See
[Add buttons](GUIDE.md#add-buttons) for an example.

- An action sends `<spot> <id> <row id>` while a row is selected, and `<spot> <id>` when none is.
- `scope` says when the ⌘K menu shows an action: `scope=item`, the default, only while a row is selected, and
  `scope=spot` always.
- A `button` of the header with `offers=actions` shows in the ⌘K menu of every card, under the spot's name, while no row
  is selected. Its press sends `<spot> <id> <card spot id>`. It isn't a command of the spot, so it gets no hotkey.
- A button whose ID is the ID of an offered button, a dot and a name, such as `button=change.draw` after
  `button=change`, shows in the submenu of that action and fits the same cards. It takes no `offers` line. → or a press
  opens the submenu, and ← goes back. A search finds its rows too.
- A filter after `actions`, a comma list, names the cards it fits by where their spot comes from: `mine`, a spot in the
  user's folder or a file of it that doesn't load; `core`, a spot that comes with Openspot and can be turned off; and
  `builtin`, a spot of Openspot itself, such as Settings. With no filter, it fits every card.

```sh
#!/bin/sh
# title=Stars
#
# button=star
# title=Star
# offers=actions
[ "$1" = star ] && echo "$2" >> "$OPENSPOT_DATA/starred"
```

- In a JavaScript spot, `when=<function>` on an offered button names a function that says whether the action shows on a
  card. ⌘K calls it with the card's spot ID and its origin, `mine`, `core` or `builtin`, and shows the action when it
  returns `true`. Keep it fast: the menu waits 2 ms for it, and an answer that comes later joins the open menu. A
  function that throws says no, and an action that its function hides hides its submenu too.
- `hotkey=<function>` on an offered button of a JavaScript spot names a function that returns the card's hotkey, such as
  `ctrl+option+n`, or nothing. ⌘K calls it as it calls `when`, and the action's row ends in that key.
- The ⌘K menu lists the spot's own actions first, then Openspot's under them, then the actions of other spots, grouped
  by spot, A to Z by its name. Each group of another spot has a header, which a search hides. Openspot's own actions, such as Edit,
  Delete and Change Icon, come from its built-in spots in the same way.
- `close=true` closes the panel after the call. `confirm` asks for a second press.
- A button `shortcut` is a letter, a digit, `return`, `backspace` or `,`, after `cmd+`, `shift+`, both or neither, such as
  `cmd+shift+n`, or `escape` alone. A row `shortcut` is any text (see [Rows](#rows)). The user gives a `button` in the
  header its hotkey with Keys… in the ⌘K menu of a card.
- An action needs a `title`. `openspot check` reports an action with no title, or with a shortcut it can't use.
- `shortcut=escape` presses the button instead of closing the sheet, like a Cancel button.
- In a ⌘K menu of more than 5 rows, a field searches them, so only a `shortcut` with `cmd` works there.
- Return on a row runs the action `open`. `button=open` gives it a `title`, and `close=false` keeps the panel open after
  a pick.
- A button with `form=true` asks for values first. Its call runs once with empty stdin, and prints a `title` in its head
  and one `field`, `choice` or `switch` for each value. Then the same call runs again with the values on stdin.
- A form with only one `choice` shows its options as rows under the search field. Return or a click sends one.
- With `type=multiple`, a choice picks several options. A checkmark marks each option in a `value` line. Return sends the
  option of its row, and `⇧⌘A` sends each option without a checkmark. The spot keeps the picks and prints the form again.
- A form can print itself again, such as with a `title` that says what's wrong. Then it stays open.
- When the call with the values prints `select=<row id>` in its head, that row is selected after the sheet reads again,
  such as the row that the form made.

## Rows

Rows are a list that the user searches and picks from. See [Show a list](GUIDE.md#show-a-list) for an example.

| Key        | Meaning                                                                                        |
| ---------- | ---------------------------------------------------------------------------------------------- |
| `row`      | The id. A pick sends `<spot> open <id>`.                                                       |
| `title`    | The first line. By default, the id.                                                            |
| `detail`   | The line under the title.                                                                      |
| `icon`     | The icon.                                                                                      |
| `parent`   | Where the row sits in its spot. The main search shows `<spot> › <parent>`.                     |
| `tone`     | A dot of its colour on the icon.                                                               |
| `value`    | `true` draws a checkmark at the end.                                                           |
| `hides`    | The id of an action that this row doesn't offer. One line for each action.                     |
| `keywords` | Words that find the row but don't show, split by commas.                                       |
| `shortcut` | Any text, such as `⌃⌥K`, that shows at the end of the row.                                     |
| `type`     | `hotkey`: a pick records a new hotkey and sends `<id> <hotkey>`.                               |
| `shake`    | `true` lets a shake of the pointer, or a tap of one modifier, be the hotkey a pick records.    |
| `pin`      | `top` or `bottom`: the row stays above or under the rows that scroll, even in a search.        |
| `focus`    | The line under the title while the row is selected, in place of `detail`.                      |
| `open`     | What Return does on this row, in place of the `title` of `button=open`.                        |
| `close`    | `false` keeps the panel open after a pick of this row, or a hotkey it records.                 |
| `file`     | The file the row stands for. See [Files out](#files-out).                                      |
| `push`     | A page that a pick pushes, in place of `<spot> open <id>`, with `push.spot` and `push.title`. See [Pages](#pages). |

- Rows go into a `repeat`, or into a plain list when there's none.
- Openspot searches the rows itself, and puts recent picks first. `recents=false` in the head turns that off, and
  `search=off` shows the rows with no search field.
- `⌘↓` selects the last row, and `⌘↑` the first.
- With `on=sheet.text`, each change of the sheet's search text asks the spot, and the spot prints the rows that match.
  It also asks when the sheet opens, as `on=sheet.open` does. Each call gets the search text on stdin as
  `search=<text>`.
- A `repeat` has its own `grid=` lines, in which each word is the place of one row. The layout repeats down for as long
  as there are rows. Rows take the places in the order each word first shows.

```ini
repeat=photos
grid=a a b c
grid=a a d e
```

- A row draws its `icon`, `title`, `detail`, `tone`, `value` and `shortcut`. To show more, give the row an action, or
  draw it with a `view`.

### Pages

A page is a sheet of a spot that shows the detail of one of its rows, and a flow is the row of sheets that the person
went through. A spot pushes a sheet onto the flow and pops its own sheet off it. See
[Open a row as a page](GUIDE.md#open-a-row-as-a-page) for an example.

| Key                   | Where                  | Does                                                                                 |
| --------------------- | ---------------------- | ------------------------------------------------------------------------------------ |
| `pages=<pattern>`     | the header             | A page that a push may show of this spot, such as `text:*`. One line for each.       |
| `push=<page id>`      | a row, or a press      | Pushes that page over the sheet that shows. On a row, `push=true` pushes the row's id. |
| `push.spot=<spot id>` | a row, or a press      | Pushes a sheet of that spot instead. With no `push=`, its first sheet.               |
| `push.title=<words>`  | a row, or a press      | The title of the pushed sheet, which its edge names. By default, the row's title.     |
| `push.replace=true`   | a row, or a press      | The pushed sheet takes the place of the one that shows, so going back skips it.       |
| `pop=true`            | a press                | Takes the spot's sheet off. On its first sheet, that goes back to whoever pushed it.  |
| `pop=all`             | a press                | Goes back to the spot's first sheet.                                                  |

- Each call of a page, a read or a press, gets the page's id in `OPENSPOT_PAGE`. The first sheet of a spot gets none.
- A press moves the flow with the keys in the head of its frame. A read never moves it, and a frame moves it one way at
  most: a push or a pop.
- A pushed page must match a `pages=` line of the spot that shows it, where `*` stands for any text. A spot with no
  sheet gets the call `<spot> open <page id>` instead of a push.
- A spot takes off only its own sheets. It never takes off another spot's sheet and never closes the panel.
- The panel keeps the last 20 sheets. `⌘[` or a swipe to the right goes back, `⌘]` or a swipe to the left goes forward, Esc
  and `pop=` take the sheet off so that nothing waits ahead, and `⌘Esc` goes back to the grid. A line left of the sheet
  stands for each sheet behind it, and a line right of it for each sheet ahead. A sheet
  that comes back shows what it last showed at once, and reads again.
- `openspot spot open <id>` starts a new flow on a spot. `openspot spot push <id> [page] [--replace] [--title <words>]` and
  `openspot spot pop <id> [--all]` move the flow that shows, as the keys do.

## The head

The head is the block of a frame that starts with one of its keys. Openspot doesn't draw it. It holds the layout and the
effects of the frame.

- Its layout keys: `grid=` and `grid.<size>=` lines, `main`, `title`, `detail` and `active` for the card, `recents` and `search`.
- `shown=true` puts the card of a spot of the app on the grid, and `shown=false` takes it off. Openspot skips it in
  the frame of any other spot.
- Its effects:
  - `toast=Saved` shows a short message at once, even when the panel is closed;
  - `link=<url>` opens the URL;
  - `progress=<0 to 1>` shows progress. With it, `title` and `detail` show only while the call runs, and `title`
    names the work on the working card (see [The life of a call](#the-life-of-a-call));
  - `background=true` marks a call that goes on while the person does other things, such as an agent that builds. It
    gets no working card in the middle of the screen: its `title` shows at the end of the search row, and a press of it
    opens the spot;
  - `select=<row id>` asks the spot again with that row selected;
  - `push=`, `push.spot=`, `push.title=`, `push.replace=` and `pop=` move the flow after a press: see [Pages](#pages);
  - `call=<n>` and `end=<n>` mark the calls of a staying spot (see [Modes](#modes)).
- The head can come anywhere in the frame. Openspot skips and reports a second head.

## The main block and the card

The main block stands for the spot on its card and in the menu bar.

- `main=<id>` in the head names it. Without `main=`, the main block is the only `text`, `number`, `graph`, `switch` or
  slider in the frame.
- The menu bar and a card of other spots show a main `text`, `number` or `graph`.
- `active=true` in the head shows on the card that the spot's thing is on, and `active=false` that it is off.
- A spot has a sheet when its header has `on=sheet.open`, `on=sheet.text`, a `clock`, `offers=search`, or `mode=stay` or
  `always`. Without any of these, such as with only `on=panel.open` or `on=app.front`, it has no sheet, and its rows
  never show.
- Without `grid.<size>=` lines, a spot shows the default card: its icon, title and detail, and an arrow when it has a
  sheet.
- When a frame holds only one `switch` or one slider, the card draws it, and a press of the card changes it. A card
  that is a switch is active while the switch is on.
- A press on the card outside a control opens the sheet, or sends `<spot> open` when there's no sheet or the header has
  `press=open`. With `press=open`, **Open** in the ⌘K menu opens the sheet. A press with `⌘` opens the spot's
  [Settings](#settings).

## Events

An event makes Openspot ask a spot what to show. The header lists the events where that is safe. See
[Respond to the Mac](GUIDE.md#respond-to-the-mac) for an example.

- An event is a word `<noun>.<verb>`. It can carry a value. The table gives the value of each event Openspot raises, and
  `openspot event emit` gives the value of any other.
- Each `on=` line names one event. Text after a space is a filter: a regular expression that the event's value must
  match.
- Only an event with a value takes a filter: `search.text`, `app.front`, `app.update`, or an event that a spot emits. A
  filter on any other event is an error. `sheet.text` takes none either, because the spot answers every search of its
  sheet.
- Openspot never asks a spot with no event. A press of its card sends `<spot> open`.
- Each read gets the event in `OPENSPOT_REASON` and its value in `OPENSPOT_VALUE`.
- Openspot measures the load once for all the spots that list `system.load`, and only while one of them is wanted.

```sh
#!/bin/sh
# title=Load
# on=system.load
# offers=menubar
printf 'text=load\ntitle=%s\n' "${OPENSPOT_VALUE:-cpu=0 memory=0}"
```

| Event              | When Openspot raises it                                                   | Value         |
| ------------------ | ------------------------------------------------------------------------- | ------------- |
| `sheet.open`       | When the spot's sheet opens.                                              |               |
| `panel.open`       | Each time the panel opens, and once when the app starts.                  |               |
| `clock.<seconds>`  | Every that many seconds while the spot is wanted, and when the Mac wakes. |               |
| `search.text`      | At each change of the main search text.                                   | the text      |
| `sheet.text`       | At each change of the sheet's search text, and when the sheet opens.      | the text      |
| `clipboard.change` | When the clipboard changes.                                               |               |
| `app.front`        | When another app comes to the front.                                      | its bundle ID |
| `app.update`       | When Openspot has downloaded an update.                                   | its version   |
| `app.launch`       | Once when Openspot starts.                                                |               |
| `screen.wake`      | When the screen wakes.                                                    |               |
| `system.load`      | Every 5 seconds while the spot is wanted.                                 | `cpu=<percent> memory=<percent>` |
| `power.change`     | When the Mac moves to another power source, or its battery gains or loses a percent. | `ac`, `battery` or `ups` |
| `disk.mount`       | When a disk or a volume mounts.                                           | its path      |
| `device.connect`   | When a USB device connects. A Bluetooth device raises no event.           | its name      |

- Openspot also asks a spot for these reasons, which aren't events:
  - `spot.change`: after a call that printed nothing;
  - `spot.want`: when a spot becomes wanted and no event has asked it yet.
- `openspot event emit <event> [value]` raises an event, from a spot or a terminal. If Openspot isn't running, it starts
  first.
- A spot must list each event it raises in `emits`, such as `emits=music.track`. `openspot check` reports an `on` event
  that neither Openspot nor any spot raises.
- A read must not raise the event that caused it. `openspot check` warns of a spot whose `on` and `emits` share an event.
- A spot is **wanted** while its sheet, the menu bar or a card of other spots shows it, and while the open panel asks it
  at `panel.open`.
- A `clock`, and events other than `sheet.open`, `sheet.text` and `search.text`, ask a spot only while it's wanted.
  `app.update` and `app.launch` ask each spot that lists them, wanted or not.
- A read must be safe at each event its header lists. Only you can make sure of that. A spot has one read at a time.

## The calls

A call asks a spot to do one thing. It works like a CGI call: arguments, variables and stdin go in, and a frame comes
out.

| Call                               | When                                                                      |
| ---------------------------------- | ------------------------------------------------------------------------- |
| `<spot> read`                      | An event that its header lists.                                           |
| `<spot> open [row id]`             | A pick of a row, or a press of a card with no sheet or with `press=open`. |
| `<spot> <id> [row id] [value]`     | A change or a press of a block.                                           |
| `<spot> drop <path> [path]...`     | A drop of files on its card.                                              |
| `<spot> drag <row id> [row id]...` | A drag of rows that stand for files out of its sheet.                     |
| `<spot> <command>`                 | A press of the hotkey the user gave a command.                            |
| `<spot> <command>`, `<spot> open`  | A [slash command](#slash-commands), with `search=<text>` on stdin.        |

- `read` is the only reserved call. `open`, `drop` and `drag` are default ids. A block can't use them, but a button can
  use `open`.
- A new default id reaches only a spot that asks for it.
- A drop on a card waits for the card's running call. A drop on a card with rows opens its sheet, and the frame can
  select the new row with `select=`.
- A spot's hotkeys run one at a time, in order, and never stop a call. A staying spot gets each press at once, in
  order, so a second press can end the call of the first, while fewer than 8 calls of its hotkeys are open. Openspot
  drops a press past that with a toast. Only the user gives a command a hotkey.

Each call has three parts:

- **Arguments:** the id, its row, then its values, so that `case "$1"` handles each call. A value over 64 KB goes only
  on stdin.
- **Variables:** `OPENSPOT_REASON` and `OPENSPOT_VALUE` of a read, `OPENSPOT_PAGE`, the page that shows, `OPENSPOT_SETTING_<KEY>`, the value of each
  `field` of the header that has one, with its key in capitals and `_` for any other sign (see [Settings](#settings)), `OPENSPOT_ID`, the spot's id, `OPENSPOT_DATA`, a
  folder for its files that one spot folder shares, `OPENSPOT_SH`, the shell helper, `PATH`, and `LC_ALL`, which is
  `en_US.UTF-8`, so each tool reads text as UTF-8 and writes numbers and dates one way on every Mac. A command that
  handles raw bytes or needs byte order sets `LC_ALL=C` for itself, such as `LC_ALL=C sort`, since `sed` and `tr` fail
  on text that isn't UTF-8, and `sort` and `[a-z]` follow the locale. `PATH` holds the
  `openspot` command first, then the paths of the user, then `/opt/homebrew/bin`, `/usr/local/bin`, `/usr/bin`, `/bin`,
  `/usr/sbin` and `/sbin`. Five more are for the spots that ship inside Openspot: `OPENSPOT_CONFIG`, the folder of the config,
  `OPENSPOT_SPOTS`, the spots folder when it isn't `spots` in that folder, and for the sheet that changes a spot,
  `OPENSPOT_EDIT`, the id of that spot, `OPENSPOT_EDIT_FILE`, its file when the user owns it, and
  `OPENSPOT_EDIT_FAILURE`, its last failure.
- **Stdin:** one block of what the user filled in and typed: a line for each field of the sheet, `search=` with the
  search text, and a `form=` line for each other text the user may have meant, such as the same keys in another
  keyboard layout. A value that isn't a field comes as `value=`.
- An action or a pick on a row that holds keys of its own, such as `meeting=`, also gets every key of that row on
  stdin. The calls of a form don't.
- Each process that the spot starts inherits its stdin, with the value of each secret and the keys of the row, unless
  the spot reads it first or closes it for that process, such as `curl "$url" </dev/null`.

```ini
title=Groceries
search=milk
form=ьшдл
```

The shell helper reads and writes values for you:

| Function                                    | Does                                                                                                  |
| ------------------------------------------- | ----------------------------------------------------------------------------------------------------- |
| `esc <text>`                                | Prints text as a value.                                                                               |
| `value <key>`                               | Prints each value of the key from stdin, one per line, in order.                                      |
| `openspot_value <key> <text>`               | Prints each value of the key from a text, such as the frame that an `openspot` call prints.           |
| `openspot_input`                            | Prints the stdin of the call as it came.                                                              |
| `openspot_kv <key> <value>`                 | Prints one line, with its value escaped.                                                              |
| `openspot_row <id> <title> [detail] [icon]` | Prints one row.                                                                                       |
| `openspot_rows [kind]`                      | Prints a row, or a block of that kind, for each tab-separated line of stdin: id, title, detail, icon. |
| `openspot_serve <function> "$@"`            | Runs the function with the three parts of each call, in each mode.                                    |
| `openspot_keep <file> [text]`               | Keeps the text, or all of stdin, in the file as a whole, so a reader never gets half of it.           |
| `openspot_paste <text>`                     | Pastes the text into the front app, then puts back the text that the clipboard held, or clears it.    |

- Loading the helper reads all of stdin, except in a staying spot, and keeps it in memory. So read the stdin of a call
  with `value` or `openspot_input`, not with `cat` or `read`: the function of `openspot_serve` gets an empty stdin in
  each mode, and so does each process it starts.
- `openspot_keep` makes the folder of the file. When it can't write, it fails and the old file stays as it was.
- `openspot_paste` needs `uses=clipboard`. It fails when the paste fails, and puts the clipboard back first. It puts
  back the text that the clipboard held. A clipboard that held a picture, a file or nothing is cleared, so the pasted
  text never stays on it.

```sh
#!/bin/sh
. "$OPENSPOT_SH"
printf 'field=output\n'
openspot_kv value "$(value input)"
```

## Slash commands

A slash command runs a `button` or a spot that has a `placeholder`, with the text that the user typed, in one Return.
A `placeholder` says that a command takes text. A plain search finds spots; `/` runs one with text.

```text
/translate hello world     Return opens Translate, and its read gets search=hello world
buy milk /notes            Return runs notes add, with search=buy milk on stdin
```

- In the main search, `/` at the start of a word, with a letter after it, lists the header `button`s, the `scope=spot`
  `button`s of a sheet, and the spots that have a `placeholder`, whose name matches the word, and `/` alone, or after the text, lists them all. A word that matches none stays text, so
  `10/2` and `/Users` search as before.
- The first row is highlighted, ↑ and ↓ move it, and the footer names what Return runs. Each row's detail is its
  `placeholder` until text follows, then the text that Return sends.
- The text is the rest of the line, trimmed. The call gets it as `search=<text>` on stdin, with the arguments of a plain
  press, so `case "$1"` handles it as any other call. With no text, a `button` runs as its hotkey does, and a spot does
  what Return does on its card.

| Command                                | The call with text                                 |
| -------------------------------------- | -------------------------------------------------- |
| A `button` with a `placeholder`        | `<spot> <id>`                                      |
| A spot with a `placeholder`, no sheet  | `<spot> open`                                      |
| A spot with a `placeholder` and sheet  | Its sheet opens, and the read of the sheet gets it |

- The first frame of the call decides what shows. A frame with fields is a form, as for a `form=true` button, and Return
  in it sends the values to the same call. Other blocks open the spot's sheet with them. A frame with nothing to show,
  such as only a `toast`, or the end of the call closes the panel, unless the `button` has `close=false`.
- A header `button` with `confirm` isn't listed, since a slash command doesn't ask twice.

## The life of a call

A call starts, prints and ends. These rules say how long it can take, and what happens when it stops.

```text
start ──► frame ──► frame ──► ... ──► end        exit 0: done; another code: the last line of stderr shows
  │                                    ▲
  │   a read must print its first      │
  │   frame or end within 10 seconds   │
  │                                    │
  └──► stop: a newer value, a second press or a quit
       terminate signal, then kill; a stopped call changes nothing
```

- A `read` has 10 seconds to print its first frame or end. Other calls have no time limit.
- A call other than a `read` that runs for more than a second shows as work on the spot's card and sheet. While the
  panel doesn't show the spot, a working card in the middle of the screen shows the spot's icon, the `title` of the
  call's latest head (or "Setting up <spot>" without one) and a bar. The bar starts at the call's `progress`, or at 0,
  and keeps creeping forward until the next `progress`. When the call ends or prints a frame with blocks, the bar fills
  and the card leaves. When several spots work, it shows the oldest call.
- A frame holds at most 32 MB. Openspot stops a call that prints more in one frame, and the call fails.
- A new value of a block stops the older call of that block. A second press of a running call stops it: its process
  group gets the terminate signal, then the kill signal. A staying spot can keep a call that the user pressed again; see
  [A staying spot](#a-staying-spot). When Openspot quits, it stops every call.
- A call ends when its output closes. A stopped call changes nothing.
- Exit code 0 means success. Any other code is a failure, and the user sees the last line of stderr. A failure can print
  `link=<url>`, a page that helps fix it.
- When the last `openspot` call of a failed call failed with a page that fixes it, Openspot shows that page with the
  failure, so a spot doesn't need to pass `link=` on.
- A failed read at `panel.open` only marks its card, and goes to the app log.
- A stop can come at any time, and two calls can run at once. Never leave a file half written.

## Places

The user decides where a spot shows. A spot only offers, with one `offers` line for each place. See
[Show a value on a card](GUIDE.md#show-a-value-on-a-card) for an example.

```sh
#!/bin/sh
# title=Shelf
# on=sheet.open
# offers=card
# offers=float
```

| Place     | The spot can show                                                       | It needs                                            |
| --------- | ----------------------------------------------------------------------- | --------------------------------------------------- |
| `card`    | as a card on the grid.                                                  |                                                     |
| `search`  | its rows in the main search.                                            | `on=panel.open`, `on=sheet.open` or a `clock`       |
| `menubar` | its main block in the menu bar.                                         | a `clock`, another event, or `mode=stay` or `always` |
| `float`   | in a small window at the pointer, which a hotkey or a shake opens.      | a sheet                                             |
| `window`  | its sheet in a window of its own, in place of the panel.                | a sheet                                             |
| `actions` | a `button` of its header in the ⌘K menu of every card.                  | a line in the `button` block, not in the header     |
| `none`    | nowhere, until another spot opens its sheet with `openspot spot open`.  | no other `offers` line                              |

- A spot with no `offers` line, in its header or on a button, offers `card`. A spot with any `offers` line shows only in
  the places it names.
- A spot that offers a place without what it needs, or an unknown place, doesn't load.
- The user gives each spot its hotkey, puts spots in the menu bar, floats them, and orders and sizes the cards. A spot
  can't claim a hotkey or a place. The hotkeys are in Keys… in the ⌘K menu of its card, and the menu bar
  is in its [Settings](#settings).
- `offers=search` shows the spot's rows in the main search. It needs `on=panel.open`, `on=sheet.open` or a `clock`. With
  only `on=sheet.open`, Openspot reads the rows when it loads the spots, as it starts or after a spot changes, after each
  change of the config, and at each open of the sheet. A panel open doesn't read them. Openspot ranks the
  rows by the user's picks.
- The user can give a spot that offers `float` a hotkey, or a shake of the pointer, with Keys… in the ⌘K menu of its
  card. It shows the spot in a small window at the pointer, which stays while the user works in other apps. The spot never learns where it shows.
- A spot that offers `window` opens its sheet in a normal window, from its card, the main search or `openspot spot open`.
  The user moves, resizes and closes it, and Openspot shows in the Dock while it's open. Use it for a sheet that needs
  room, such as a catalog. The window has no title bar buttons: Esc closes it, so give a view that fills it a way
  out, such as a Done button.
- `on=search.text <pattern>` makes a spot answer the main search. Openspot asks it at each change of a text that the
  pattern matches, with no pause. A newer text stops the older call. The answer should be fast.
- Its rows show first in the main search until the newest text has an answer, and go at once when the pattern no longer
  matches. A pick of a row sends `<spot> open <row id>`.
- A spot whose only event is `search.text` has no card.
- An answer can be one card instead of rows: its head has `grid.large=` or `grid.strip=` lines, and its main block has a
  `value`. A pick of the card sends `<spot> open <value>`.
- `openspot calc solve <words>...` prints the answer to a sum, a conversion or a date as a row.
- Every spot can show in the menu bar when the user puts it there. A spot that offers `menubar` shows its main `text`,
  `number` or `graph` there. A read that prints nothing hides it until the next read. Any other spot shows its icon, and
  a click does what Return does.
- A spot with a `clock` has no card on the grid until the user adds it.

## Modes

Openspot starts a spot for each call, unless its header says otherwise.

- `mode=once` starts a process for each call.
- `mode=stay` keeps one process, which gets each call on stdin while the spot is wanted.
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
- Openspot waits 2 ms for its frame in the same keystroke, and shows a later frame on the next one.
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

Openspot writes each call to the spot's stdin as one block, then a blank line. `call=<n>` numbers the call, an `arg`
line gives each argument, an `env.<name>` line gives each variable, such as `env.OPENSPOT_REASON` of a read, and one
`input` line holds its stdin.

```ini
call=4
arg=send
input=message=Hello\n
```

- A staying spot is one process that talks both ways over stdin and stdout. Each call goes to the running process, and
  no call starts a second copy.
- `openspot_serve main "$@"` runs `main` with the three parts of each call, and prints `call=<n>` before its output and
  `end=<n>` after it. The same `main` works in every mode.
- The spot can print frames at any time. It must end each call with `end=<n>` in a head. A frame of only `call=<n>`
  starts the output of that call.
- A second press of a running call sends the block `stop=<n>`. The call ends 2 seconds later, unless the spot prints a
  frame for it first, such as a head of only `call=<n>`; then the call runs on to its `end`. That is how a spot keeps a
  window open and brings it to the front at a second press. A form, and a call stopped by a newer value of its block,
  stop at once. `openspot_serve` reads stdin only between calls, so it can't see a stop while `main` runs. A newer
  search text sends `stop=<n>` for the read of the older text, so only the newest answer shows. A read after the first gets `stop=<n>` after 10 seconds, and fails
  as a slow read.
- With `mode=stay`, the process runs while the spot is wanted, or while a call waits for its `end`. When the spot is no
  longer wanted, Openspot closes its stdin, and the spot must end, with every process it started. After 2 seconds its
  process group gets the terminate signal, and 2 seconds later the kill signal.
- After 3 failures in one minute, Openspot tells the user, and starts the spot again only when its file changes. Keep
  what must survive in `OPENSPOT_DATA`.

### A Swift spot

A spot can be a Swift program. Openspot builds it once, and runs the built program at each call. See
[Write a spot in Swift](GUIDE.md#write-a-spot-in-swift) for an example.

```swift
#!/usr/bin/env swift
// title=Cups today
// on=sheet.open
// source=cups.swift
print("text=cups\ntitle=\(cups) cups")
```

```swift
let cups = 3
```

- A Swift file with `#!/usr/bin/env swift` on its first line is a spot, with its header in `//` lines.
- Each `source=` line names one more Swift file, or a folder whose Swift files it takes, next to the spot. Openspot
  builds them into one program with the spot's file, which holds the code that runs first. Only a Swift spot takes
  `source`, and a source is a plain path inside the spot's folder, such as `source=model` or
  `source=model/cups.swift`: no `.`, no `..`, and no `/` at its start or end.
- To build it, Openspot needs the Command Line Tools. It builds again when one of the files changes, and a staying
  spot starts again then. A spot with no `source` runs as a script until its first build is done. A spot with a
  `source` waits for its build, and a build that fails is the failure of the call. Openspot doesn't build a spot
  that failed to compile again until one of its files changes.
- A shared spot carries the built program as `<name>.<hash>.program`, where the hash is the SHA-256 of its Swift
  files. A share always builds that program from the sources it ships. A Mac with the Command Line Tools builds the
  spot from its sources and never runs the carried program. A Mac with no tools runs it while that hash matches (see
  [Trust](#trust)).
- The spots that ship inside Openspot are built with the app, the same way, and run the program that the app carries.

## Views

A view draws what blocks can't: a SwiftUI view in the place of a block. See
[Draw your own view](GUIDE.md#draw-your-own-view) for an example.

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

- `view=<file>` in the header names a SwiftUI file next to the spot. A `view=<id>` block draws it in its place.
- The spot and its view must be in a folder of their own, such as `cups.spot/cups.sh` and `cups.spot/cups.swift`.
- The file declares `struct SpotView: View` with `let spot: SpotInput`, and has no top-level code.

| Member              | Gives                                                                 |
| ------------------- | --------------------------------------------------------------------- |
| `spot["key"]`       | The last value of a key of its block, or nil.                         |
| `spot.all("key")`   | Each value of a key that repeats.                                     |
| `spot.size`         | The size of its place.                                                |
| `spot.inset`        | The space other cards keep between their edge and their words.        |
| `spot.corner`       | The corner radius of the card.                                        |
| `spot.ink`          | The colour of words, for light and dark.                              |
| `spot.secondary`    | The opacity of a second line.                                         |
| `spot.accent`       | The accent colour.                                                    |
| `spot.font`         | The fonts of the cards: `title`, `detail`, `metric` and `value`.      |
| `spot.send(v)`      | Calls the spot with the view's id and `v`, as a field does.           |
| `spot.answers`      | Changes each time the spot answers a new send, to end a busy state.   |
| `spot.card(id)`     | The card of a spot, at the size it takes on the grid.                 |
| `spot.cardSize(id)` | That size, so the view can lay cards out.                             |
| `spot.sheet(id)`    | The sheet of a spot with its sample data, where a click runs nothing. |
| `spot.tip(text)`    | A tip in the look of Openspot's own, for the view to show on hover.   |
| `spot.media(path)`  | A PNG or JPEG picture, or a MOV or MP4 video, at its size or less.    |
| `spot.cornerButton` | The round button on the rim of a card, by its id and an action.       |
| `spot.columnGap`    | The gap between the columns of the grid.                              |
| `spot.rowGap`       | The gap between the rows of the grid.                                 |
| `spot.columns`      | How many columns a window holds.                                      |
| `spot.tipDelay`     | How long the pointer rests on a control before its tip shows.         |
| `spot.rows`         | Each `row` block of the frame, in a sheet or a window, in order.      |
| `spot.isShown`      | Whether its place shows now. It's false while the panel is hidden.    |
| `spot.close()`      | Closes the sheet, the float or the window of its spot.                |

- The view fills its place, and the whole card when there's no card layout. It can't change the size of its place.
- In a window (see [Places](#places)), a sheet with one `view` block fills the window. `spot.card(id)` draws the card of
  any spot by the ID that `openspot store list` prints, as the store does. `spot.sheet(id)` draws its sheet with what its
  `sample.sh` prints (see [A spot](#a-spot)), and draws nothing for a spot with no sample.
- It gets the keys of its block in each frame. A new frame keeps its `@State`.
- On a card, the view only draws, and a press works as on any card. In a sheet, it takes clicks and keys, and
  `spot.send(value)` calls the spot with `<id> <value>`, as a field does. A newer send stops the call of the older one.
- Openspot compiles it when its card first shows, and again when the file changes. A view that doesn't compile shows its
  first error, and `openspot check` prints it.
- A shared spot carries the compiled view as `<name>.<hash>.view`, where the hash is the SHA-256 of Openspot's view
  code and the source. Openspot uses it instead of the source only while that hash matches.
- Each row of `spot.rows` has its `id`, `row["key"]` for the last value of a key and `row.all("key")` for each
  value, as the view's own block has. In a sheet, Openspot still draws the rows under the view. In a window that one
  view fills, only the view draws them. A card gets no rows. A `view` block takes no `row` key of its own, and
  `openspot check` reports one.
- `spot.close()` closes only the open sheet, the float or the window of the view's own spot. It does nothing on a card,
  in the sheet that `spot.sheet(id)` draws, and in a card that `spot.card(id)` draws. A view can call it from any thread.
- Openspot removes a view while its place is hidden, and builds it again at the next show, so its `@State` starts
  anew. A view that reads `spot.isShown` stays built instead, and must stop its timers and its motion while it's false.
- `openspot spot stats` counts each run of the `body` of `SpotView` and the time of that one `body` (see
  [Stats](#stats)). It doesn't time the bodies of the views inside it, which SwiftUI runs later.
- `SpotView` must not declare a method named `update()`: Openspot keeps that name, and SwiftUI would call it before
  each `body`.
- The view runs inside Openspot, so a crash quits Openspot. Do the work in the spot, and only draw in `body`.

## Cards of other spots

A card of other spots shows the main blocks of the spots it names. See
[Combine spots on one card](GUIDE.md#combine-spots-on-one-card) for an example.

- Each `grid.<size>=` line is one line of the card at that size, as in [Layouts](#layouts). Here each word is the id of
  another spot, not of a block. That spot's main block fills the cells its id covers.
- `to=` names the spot that opens when the user presses the card. Without `to=`, a press does nothing.
- While the card shows, Openspot asks each spot it names, at that spot's own events. A spot with no event that would ask
  it, such as one with only `on=sheet.open`, is asked with `spot.want`. Each named spot must have an `on=` event.
- The best spots to name have a `clock` and a main `text`, `number` or `graph`.
- Openspot looks for each id in the card's folder first, then among all spots.
- Each line of one size must have the same number of words, and each id must cover a rectangle. All lines use one size.
- The header takes only `title`, `icon`, `detail`, `keywords` and `to` next to its `grid.<size>=` lines. Openspot doesn't
  load a card with any other key, because the card runs no code.

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
  call prints nothing, Openspot asks the spot again.
- Dragging the icon in the head of the sheet drags every row that has a `file`.

## The openspot command

A spot asks the Mac and Openspot for things through one command, which works the same in a terminal.

- Each capability is `openspot <noun> <verb>`.
- A noun names its commands, its events and its use, such as `openspot clipboard copy`, `clipboard.change` and
  `uses=clipboard`.
- A call that reads files or asks the Mac gives the same answer whether Openspot is running or not. A call that needs the
  running app starts it, and waits up to 10 seconds.
- Ctrl-C stops a call, and the stopped work changes nothing.
- `openspot help` lists each capability. `openspot help <noun>` prints the guide of a noun, such as `screen` or
  `calendar`.
- A capability that can't answer prints `status=<word>`. A capability that keeps state keeps it in its own helper.
- `openspot translate` prints `status=unknown` when it cannot tell the language of the text, `status=missing` when macOS
  has not downloaded a language, `status=unsupported` when it knows no way between the two, and `status=failed` for any
  other fault. `openspot calc solve` prints `status=offline` or `status=unavailable` for a currency with no rates.
- When macOS already has a command, such as `open`, use it. For the screen and the clipboard, use `openspot screen` and
  `openspot clipboard`, so that the user sees each use.
- These calls fail in a read, so that a read changes nothing and opens nothing:
  - calls that wait for the user: `color pick` and `folder pick`;
  - calls that capture the screen: `screen shot`, `screen record start` and `screen record stop`;
  - calls that change the Mac or the user's data: `window move`, `clipboard copy`, `clipboard paste`, `calendar add`,
    `reminders add`, `reminders done`, `spot add`, `spot remove` and `spot delete`;
  - calls that change Openspot or its places: `app quit`, `update install`, and `setting set` of a key that Openspot
    keeps for the user (see [Settings](#settings));
  - calls that open a window or the panel: `spot show`, `spot open`, `spot choose`, `spot settings`, `spot edit`, `spot prompt`, `spot share`, `spot review`, `grid edit`, `setting change`,
    `update check`, `calendar show` and `reminders show`.
- `calendar add --dry-run` and `reminders add --dry-run` change nothing, so they work in a read.
- `openspot batch` runs one call for each line of stdin, and prints `---` after each. It stops at the first failure.
- `--frame` makes `app status`, `account`, `spot list`, `store list` and `setting list` print blocks instead of JSON.

The commands that try a spot are in [Try your spot](GUIDE.md#try-your-spot). The others:

| Command                                            | Does                                                                                            |
| -------------------------------------------------- | ----------------------------------------------------------------------------------------------- |
| `openspot guide`                                   | Prints the guide, then this protocol.                                                           |
| `openspot spot show <id>`                          | Opens the panel with the spot selected.                                                         |
| `openspot spot open <id>`                          | Opens the panel on a spot, as a new flow. See [Pages](#pages).                                  |
| `openspot spot push <id> [page]`                   | Pushes a spot, or a page of it, over the flow that shows. See [Pages](#pages).                  |
| `openspot spot pop <id> [--all]`                   | Goes back one sheet of a spot that shows, or to its first sheet. See [Pages](#pages).           |
| `openspot spot choose <id>`                        | Asks for files, and drops the chosen ones on a spot that takes them, as a press of its card does. |
| `openspot spot settings <id>`                      | Opens the Settings of a spot, as Settings in its ⌘K menu does.                                  |
| `openspot spot edit <id>`                          | Opens the Edit sheet of a spot, as Edit in its ⌘K menu does, or a file that doesn't load in the text editor. |
| `openspot spot prompt <id>`                        | Copies a prompt that asks a coding agent to change a spot.                                      |
| `openspot spot share <id>`                         | Shares a spot, as Share in its ⌘K menu does.                                                    |
| `openspot spot delete <id>`                        | Moves a spot to the Trash, and `⌘Z` in the panel puts it back.                                  |
| `openspot spot add <git url, folder or .spot>`     | Adds a spot, and records it in `spots.lock`. An update that needs a new use also needs `--yes`. |
| `openspot spot remove <id>`                        | Moves a spot that `spot add` added to the Trash.                                                |
| `openspot spot stats`                              | Prints what each spot cost and used. See [Stats](#stats).                                       |
| `openspot grid edit`                               | Opens the panel in Edit Spots, to arrange the grid.                                             |
| `openspot store list [--frame]`                    | Prints each spot of the store and its step: `get`, `publish`, or `added` once you have it.      |
| `openspot store get <id>`                          | Gets a spot of the store: turns it on, or adds its package to your spots folder.                |
| `openspot store add <folder>`                      | Adds a folder that holds spot folders as a store, so the Store lists its spots. The folder's name is the store's name. |
| `openspot store remove <folder>`                   | Removes a store that `store add` added. The spots you got from it stay.                         |
| `openspot store folders [--frame]`                 | Prints the built-in store Openspot, which holds the examples, then each store that `store add` added, with its name and whether its folder is found. |
| `openspot store publish <id>`                      | Publishes a spot of your spots folder to the store. It needs a `readme.md` beside its script. Only the Store spot can run it, so you publish from the Store spot. |
| `openspot playground [file]`                       | Opens the Playground on a spot that you type or on a file.                                      |
| `openspot check --sheet`                           | Reports the faults of a sheet on stdin.                                                         |
| `openspot render --card <size> <file.png>`         | Draws the card of the sheet on stdin at a size, such as `wide`, to a picture.                   |
| `openspot render --spot <id> <file.png>`           | Draws the sheet of an installed spot, or with `--card <size>` its card, to a picture.           |
| `openspot render --panel <file.png>`               | Draws the panel with each installed spot on its grid.                                           |
| `openspot render --store <file.png>`               | Draws the window of the Store with each spot as its card.                                       |
| `openspot prompt new [words]...`                   | Prints a prompt that asks a coding agent to build a spot that does what the words say.          |
| `openspot prompt change <id> [words]...`           | Prints a prompt that asks a coding agent to change a spot as the words say.                     |
| `openspot emoji [--tone name]`                     | Prints each emoji as a row, with its name in the language of the Mac.                           |
| `openspot symbols`                                 | Prints each symbol of the Character Viewer as a row.                                            |
| `openspot translate [--from code] [--to code]`     | Translates the text on stdin. `openspot translate languages` prints the languages it knows.     |
| `openspot account [--frame]`                       | Prints the public facts of the account that signs what you publish. See [Trust](#trust).        |

### Settings

A setting keeps a choice of the user. Each spot has its own Settings, a sheet apart from its own rows, which `⌘` Return
on its card, a press of the card with `⌘`, or **Settings** in its ⌘K menu opens. Return does the spot's main act, and
`⌘` Return sets it up. See [Let the user choose a setting](GUIDE.md#let-the-user-choose-a-setting) for an example.

- The Settings of a spot list each thing the user can change about it, in this order: first what the spot itself does,
  each `field`, set or not, and each value it keeps that no `field` names, such as a look; then its shortcuts, the
  hotkey of each `button` in its header; then **Float** when it has a view to float, its sheet; and last **Show in the
  menu bar**, which every spot has.
- Each shortcut is a row with `type=hotkey` (see [Rows](#rows)). Return on it records a key, and `⌘⌫` removes the key.
- Openspot makes the Settings sheet, and it grows from the spot's card. Its rows never show in the spot's own sheet.
- The Settings spot of Openspot holds only the settings of the app: its keys, Careful mode, Open at login and the
  `openspot` command.
- A `field` block in the header names a setting. Return on it runs the action with the same id, which can answer with a
  form. `⌘⌫` removes the value.
- Each call gets the value of each `field` in `OPENSPOT_SETTING_<KEY>`, such as `OPENSPOT_SETTING_FOLDER`, so a spot
  reads its settings with no `openspot` call. A spot never gets the settings of another spot this way.
- `type=secret` on a header `field` keeps a value such as a key of a service. Return on its row asks for the value in
  Openspot's own form. Each call gets it only on stdin, as `setting.<key>=<value>`, never in a variable or an argument.
  Settings show only that it is set, and Openspot hides it in the call log, the stats, a toast and a failure line.
- Openspot keeps a secret in the Keychain, under the spot's id and the field's key, never in the config. Only a
  `type=secret` field of that spot gets it, and it goes when the spot is removed. See [Trust](#trust).

```sh
#!/bin/sh
# title=Weather
# on=sheet.open
#
# field=city
#
# field=token
# type=secret
. "$OPENSPOT_SH"
printf 'text=city\ntitle=%s\n' "${OPENSPOT_SETTING_CITY:-Paris}"
if [ -n "$(value setting.token)" ]; then printf 'text=token\ntitle=Signed in\n'; fi
```

- A secret has 8 characters or more. Openspot hides only the exact value, so a part of it or another form of it, such
  as its base64, still shows.
- `openspot spot run` in Terminal and `openspot check` pass no settings. A value over 64 KB isn't put in a variable.
  Two keys that give one variable, such as `api-key` and `api_key`, are a fault of the header.
- `openspot setting get <key>` prints the value, or nothing, and `•••` for a secret that is set. `openspot setting set <key> [value]` keeps the value, or
  removes it when there's no value. In a terminal, `--spot <id>` names the spot.
- Keep a choice of the user in a setting. Keep what the spot makes, such as a cache, in `OPENSPOT_DATA`.
- Openspot keeps some keys for the user, and a `field` can't use them:
  - of any spot: `icon`, the path of a picture that draws in place of the header's icon, which Change Icon in the menu
    of a card keeps; `enabled` and `menubar`, `true` or `false`, and `open`, `float` and `key.<command>`, a hotkey such
    as `ctrl+option+k`, `shake`, or one modifier alone, such as `option`, which a tap of that key presses, or no value
    to remove it. The key of `open` does what a press of the spot's card does, from any app;
  - of the spot `openspot`, which is the app: `login`, `link` and `careful`, `true` or `false`, and `panel-key` and
    `fix-key`.
- Each of these keys needs the use of the call that does the work (see [Trust](#trust)).

### Stats

Openspot counts what each spot cost and used, so that the user can see it.

```sh
openspot spot stats --days 7 --frame
```

- Openspot keeps one file for each day, for 90 days. Today's numbers are live.
- `--days N` adds up the last N days. `--spot <id>` shows one spot.
- `--frame` prints a `row=<id>` block for each spot, the most CPU first, then a `use=<n>` block for each call that needs
  a use, the newest first.

| Row key              | Meaning                                                               |
| -------------------- | --------------------------------------------------------------------- |
| `title`, `detail`    | The name of the spot, and its numbers in words.                       |
| `runs`, `failures`   | The calls that ended, and those that failed.                          |
| `cpu`, `seconds`     | The CPU seconds of its processes, and the wall time of its calls.     |
| `read`, `written`    | The bytes its processes read and wrote.                               |
| `wakeups`            | The times its processes woke the CPU.                                 |
| `call.<noun>.<verb>` | The count of one call that needs a use, such as `call.screen.shot=2`. |
| `network`            | `declared` when its header names `network`.                           |
| `bodies`, `body`     | The runs of the `body` of its `SpotView`, and their seconds in all.   |
| `fault`, `tone`      | Its last error, with `tone=bad`.                                      |

- A `use` block holds `time`, `spot`, `call`, such as `app.quit`, and `declared`, `true` or `false`.

## Trust

A spot runs with the user's rights. Openspot shows what a spot can do, and what it did.

```sh
#!/bin/sh
# title=Coffee
# uses=app
openspot app quit
```

- Openspot asks nothing in daily use. It shows what a spot can do when the user adds or updates it, and shows each use
  after it happens.
- Openspot knows which spot makes each call of `openspot` from its own records, not from the variables of the process.
  Only the user's own processes can reach the API.
- No spot and no Terminal reads a secret (see [Settings](#settings)): `setting get` and `setting list` print `•••` for
  it, to its own spot too, and `setting set` of it fails. Only Openspot's own form changes it.
- `uses` names what a spot uses. Openspot doesn't load a spot with an unknown use.

| Use         | The calls that need it                                                                                                                                          |
| ----------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `app`       | `app quit`, `update check`, `update install`, and `setting set` of `menubar`, `open`, `float`, `key.<command>` or of the spot `openspot`                                |
| `spots`     | `spot add`, `spot remove`, `spot settings`, `spot edit`, `spot prompt`, `spot share`, `spot delete`, `spot new`, `spot run`, `spot log`, `setting list`, `setting set` of `enabled`, and `setting get`, `set` or `change` of another spot |
| `screen`    | `screen sources`, `screen shot`, `screen record`, `window frame`, `window move` and `color pick`                                                                |
| `clipboard` | `clipboard copy`, `clipboard paste` and `clipboard read`                                                                                                        |
| `calendar`  | each call of `calendar` and `reminders`                                                                                                                         |
| `network`   | No call. The spot reaches the network.                                                                                                                          |
| `files`     | No call. The spot writes outside its data folder.                                                                                                               |
| `account`   | `store publish`. Only a spot that ships inside Openspot can have it.                                                                                            |

- A call that needs a use the header doesn't name still runs, and shows one toast for each spot, use and day.
  `openspot check` can't report it, because only a run shows it.
- Before an add, the review shows the title, the `uses`, and a line **Can also** with what the code seems to do but
  doesn't name: the network, `rm`, `screencapture`, `pbcopy` or `pbpaste`. It warns, and never blocks the add.
- The review names each file that Openspot can't show as text, such as the built program of a Swift spot or a built
  view, and says that it can do all that the user can. For a built file, it says that the source beside it may not
  match. Openspot can't prove that a built file comes from its source: it only skips one whose name doesn't hold the
  hash of the source that is there now.
- So Openspot runs the program that a Swift spot carries only in two cases: the spot ships inside Openspot, or the Mac
  has no Command Line Tools, where the review has said that the program may not match its source. On a Mac with the
  tools, a spot that the user added runs only what Openspot built there from the source the user can read. A share
  never passes a carried program on: it builds a new one from the sources it ships.
- An update with no new use applies quietly. An update with a new use waits for `--yes`.
- Careful mode is a setting of the user, off by default. It runs each process of a spot in a sandbox: no network unless
  `uses=network`, and writes only to its data folder and the temp folders unless `uses=files`. With `uses=screen`, it
  can also write to the Desktop, Movies and the screenshots folder. In Careful mode, a call that needs a use the header
  doesn't name fails.
- Without Careful mode, the data folder is no boundary.
- A spot folder can hold `releases.jsonl`, the signed releases of the spot. Openspot writes it when the user shares or
  publishes the spot, and refuses a shared spot whose files don't match its last release. A spot reads nothing from it.
- `openspot account` tells any spot the public facts: whether an account is signed in, its `npub`, the `handle` it was
  made with, the day it was made (`since`), whether its words are backed up, and whether it syncs.
- No call makes, changes or removes the account key, and none prints or takes the 12 words. Only the Account sheet of
  the app does, and it asks for Touch ID or the Mac's password before each act on the key. An unlock counts for 5
  minutes, and only for the act it was asked for. A Mac with neither a password nor Touch ID cannot unlock the key.
- `store publish` signs with the key, so it answers only a spot that ships inside Openspot and names `account` in its
  uses, and only while the app runs. The calls of such a spot stay out of the call log and the playground.
- The 12 words of an account give its key as NIP-06 says, so they open the same account in another Nostr client.

## Messages

A toast or a failure line says what happened, and why when you know it. It says what still worked, and the exact step
that fixes the rest. Use plain words, a calm tone, and one or two short sentences. Put each key in backticks.

| Instead of                    | Write                                                                                  |
| ----------------------------- | -------------------------------------------------------------------------------------- |
| `Oops! Something went wrong.` | `Openspot cannot find a screenshot.`                                                   |
| `Error 1: osascript failed.`  | ``Copied, but Openspot cannot paste. Press `⌘V`, or allow Openspot in Accessibility.`` |

## Versions

The version at the top is the version of this protocol. The guide has no version. A new word raises the minor number, such as `1.1`. A draft becomes
`final` when real use proves it, and a final version never changes the meaning of a word. A change that breaks an old
spot raises the major number, and adds a header key `protocol=<major>`. A spot without that key is version 1.

## How to extend

An old spot never sees a word it didn't ask for. An old app skips a word of a frame that it doesn't know, and doesn't
load a spot whose header has a key that it doesn't know.

| To add               | Add                                                              |
| -------------------- | ---------------------------------------------------------------- |
| A thing that happens | an event `<noun>.<verb>`                                         |
| A place to show      | a value of `offers`                                              |
| A thing to draw      | a kind `<kind>=`, which an old app skips and reports             |
| A detail of a kind   | a key, or a `type` value                                         |
| A power of the Mac   | a noun: `openspot <noun> <verb>`, its events and its `uses` word |
| A complex look       | nothing: a `view` of the spot                                    |
