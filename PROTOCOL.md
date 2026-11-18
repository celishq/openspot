# Openspot protocol

`1.1` `draft`

This is the contract between a spot and Openspot: what a spot prints, which calls it gets, and what it can ask. To learn
by example, start with the [guide](GUIDE.md).

## A spot

Openspot shows spots in three places: the **panel**, the window that the Openspot hotkey opens, with the main search and
a grid of **cards**; the **card** of each spot on that grid; and the **sheet**, the view of one spot that opens over the
panel.

A spot is a script and a manifest, `spot.toml`, that says what the script is. Openspot runs the script, and the spot
prints what to show:

```text
event   ─ on ─►  <spot> read            Openspot runs the spot
spot    ─ prints ─►  blocks             Openspot draws them
press   ─ on a block ─►  <spot> <id>    the user or an agent acts
```

- A spot lives in a **spot folder**: a folder `<name>.spot` in the spots folder, such as `coffee.spot`. The folder holds
  its `spot.toml` (see [The manifest](#the-manifest)), its scripts, its `readme.md`, its `sample.sh` and any file that
  they need.
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
- The folder is shared as one unit of at most 25 MB, with its `spot.toml`, and its scripts share one data folder. A
  script that `spot.toml` doesn't describe, and a file that isn't executable, can hold shared code.
- Openspot moves a loose script into a spot folder of its name, with the files of the same name, such as `coffee.md`,
  which becomes `readme.md`. It writes a `spot.toml` there with the script's title.
- A spot only says what it has. The user decides where it shows and which key opens it.
- An agent can do anything the user does, with `openspot spot run <id> <call>` and `openspot event emit`. A spot
  can't tell who called it.

## The keys of a spot

Every spot answers the same keys, so a person learns them once. Openspot gives each key its act, and a spot only says
what it has.

| Key          | What it does                                                                                              |
| ------------ | --------------------------------------------------------------------------------------------------------- |
| Return       | The main act of the spot: it runs the spot's one command, or opens its sheet.                             |
| `⌘` Return   | Opens the spot's [Settings](#settings): its keys, each setting and its places.                            |
| `⌘Y`         | Opens the rows of a spot whose Return runs its command, as its **History**.                               |
| `⌘K`         | Opens the menu of all acts, when it holds more than the footer shows.                                     |

- A spot with one command in its manifest, such as Dictate, runs that command on Return. Its rows are its History, on
  `⌘Y` and in its ⌘K menu. Return runs it even before it has a hotkey: the user sets one in its Settings.
- Any other spot opens its sheet on Return, such as a clipboard history.
- A press of its card, its open hotkey, a click of it in the menu bar and its slash command with no text do what Return
  does. The click in the menu bar opens the sheet under the menu bar item.
- The ⌘K menu of a card starts with the acts that Openspot adds, always in this order: first what the user does with the
  spot, the main act on Return, History and Share; then what changes it, Settings, Edit and Change Icon; then Turn off
  or a red Delete. The acts that spots offer to every card with `offers = ["actions"]` follow, under the name of their spot. A
  spot adds no act to its own card. Its sheet carries what it does.
- A card's `⌘` keys work while a search is typed, except the ones that edit the words, such as `⌘⌫`.
- Edit copies a prompt that sends an agent to the spot's file. A person changes a spot there, not in its Settings.
- A choice that stays, such as a look or a folder, is a setting in Settings, not a part of the spot's own sheet.
- A card shows an arrow when Return opens its sheet, and none when Return runs its command.
- The footer names the spot's own keys first and `⌘K Actions` last.

## The format

Everything a spot prints is lines of `key=value`.

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
- An empty value is no value. Openspot never splits a value, so a URL or a time stays whole.
- The first key of a block is its kind, and its value is the block's id. `switch=wifi` is a switch with the id `wifi`.
- The root is the block that starts with `frame=` (see [The root](#the-root)). A block that starts with any other
  unknown key is an error, and Openspot skips it.
- In a frame, Openspot skips a line with an unknown key, and `openspot check spots` reports it. In the manifest, an
  unknown key is a fault (see [The manifest](#the-manifest)).
- Anything with its own title or icon is a block of its own, such as an `option` after a `choice`.

## The manifest

The manifest says what a spot is, so that Openspot can list it, place it and give it keys without running it. It is the
file `spot.toml` in the spot folder.

```toml
title = "Weather"
icon = "cloud.sun"
on = ["sheet.open"]
uses = ["network"]

[commands.refresh]
title = "Refresh"

[settings.city]
title = "City"

[scripts.radar]
title = "Rain radar"
on = ["clock.300"]
```

- The keys at the top describe the script named after the folder, such as `weather.sh` in `weather.spot`.
  `[scripts.<name>]` describes each other script of the folder, such as `radar.sh`, with the same keys. Its commands
  and settings are `[scripts.<name>.commands.<id>]` and `[scripts.<name>.settings.<key>]`.
- A value is a string in quotes, `true` or `false`, or a list in brackets, such as `on = ["sheet.open", "clock.60"]`.
  `on`, `offers`, `source`, `pages`, `uses`, `emits` and `keywords` take a list.
- A script holds no header. A comment at its top is ordinary text.
- If a key is wrong, or is one that Openspot doesn't know, such as `titel`, Openspot doesn't load that spot, and its
  fault names the key. Other spots still load.

| Key           | Value                                                                                                                            |
| ------------- | -------------------------------------------------------------------------------------------------------------------------------- |
| `title`       | The name. By default, the file name.                                                                                             |
| `icon`        | The icon, as in a block (see [Blocks](#blocks)). A path that doesn't start with `/` starts at the spot's folder.                 |
| `detail`      | The line under the title.                                                                                                        |
| `keywords`    | More words that find the spot in the main search, such as `keywords = ["coffee", "cup"]`.                                        |
| `placeholder` | The text the spot takes in a [slash command](#slash-commands), such as `placeholder = "Text to translate"`. It lists the spot there. |
| `on`          | The events that make Openspot ask the spot what to show. See [Events](#events).                                                  |
| `emits`       | The events the spot raises. See [Events](#events).                                                                               |
| `offers`      | `search`: its items show in the main search. See [Places](#places).                                                              |
| `drop`        | The files its card takes: extensions such as `mov,mkv`, `folder`, or `*`. See [The calls](#the-calls).                           |
| `edits`       | `spots`: its sheet is also the Edit sheet of each spot. Only a spot of the app takes it. |
| `starts`      | `first-launch`: its sheet opens in place of the grid when Openspot starts for the first time. |
| `view`        | A SwiftUI file next to the spot, such as `view = "cups.swift"`. See [Views](#views).                                             |
| `source`      | The Swift files, or folders of Swift files, that a Swift spot is built with. See [A Swift spot](#a-swift-spot).                  |
| `mode`        | `once` (the default) or `stay`. A `stay` spot with `app.launch` in `on` runs from launch. See [Modes](#modes).                   |
| `uses`        | What the spot uses: `app`, `spots`, `screen`, `clipboard`, `calendar`, `power`, `network`, `files`. See [Trust](#trust). |
| `answers`     | `last`: the answers of `search.text` show under the other results, not first. See [Places](#places).                            |

| Table               | Meaning                                                                                                                                                                                                                                                                      |
| ------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `[commands.<id>]`   | A command, with its `title` and `icon`. The user can give it a hotkey. `confirm` asks for a second press. `close = false` keeps the panel open after a [slash command](#slash-commands) that shows nothing, and `placeholder` lists it there, as the grey hint after its name. |
| `[settings.<key>]`  | A setting the user chooses, with its `title` (by default, its key) and `icon`. See [Settings](#settings).                                                                                                                                                                    |

- A spot with a command in its manifest starts off the grid, and the user can add its card.
- Return on a spot with one command runs it, as its hotkey does, also when it has no hotkey yet. The user sets one in its
  [Settings](#settings). Its own rows open as its History on `⌘Y`. A spot with more commands runs them
  by their hotkeys and from its ⌘K menu, and Return on it opens its sheet, or its Settings when it has no `on`. See
  [The keys of a spot](#the-keys-of-a-spot).
- `confirm = "<words>"` on a command makes a press of its card, or its row in the ⌘K menu, ask twice: the first
  press shows the words, and the second runs the command. Its hotkey doesn't run it at once: it shows the panel on the
  spot with the words, and Return, or the hotkey again, runs it.

```toml
title = "Empty Trash"

[commands.empty]
title = "Empty Trash"
confirm = "Press again to empty the Trash"
```

```sh
#!/bin/sh
case "$1" in empty) openspot toast Emptied ;; esac
```

## Frames

A frame is everything a spot shows at one time. A spot can print several frames in one call, so it can show progress,
then the result, or change one block while the rest stays.

```text
 what the spot prints              what it is
┌──────────────────────────────┐
│ frame=                       │ ─┐
│ grid=title                   │  ├─ the root: the layout, not drawn
│ grid=wifi                    │ ─┘
│                              │
│ text=title                   │ ─┐
│ title=Wi-Fi                  │  │
│                              │  ├─ blocks: each one is drawn
│ switch=wifi                  │  │
│ value=true                   │ ─┘
│ ---                          │ ─── the end of this frame
│ switch=wifi                  │ ─┬─ a later frame with no root:
│ value=false                  │ ─┘  it changes only this switch
└──────────────────────────────┘
```

```toml
title = "Copy"
on = ["sheet.open"]
```

```sh
#!/bin/sh
printf 'frame=\nprogress=0.5\ntitle=Copying\n---\n'
printf 'frame=\n\ntext=done\ntitle=Copied\n'
```

- Openspot draws each frame as soon as it arrives.
- The first frame of a call replaces what shows. A later frame of the same call replaces it too when it holds a root.
- A later frame with no root changes only the blocks it prints. A block whose id shows takes the place of that block,
  and a block with a new id joins the end, such as a new item. The root stays as it was.
- A frame with only a root doesn't change what shows. Its `progress`, `title` and `detail` show on the running call
  (see [The root](#the-root)).
- A spot keeps no state between calls. Each call gets the values on stdin, and prints its frames again, or nothing.
- If a read prints nothing, the spot shows nothing. If another call prints nothing, Openspot asks the spot again.
- When a newer change makes a call out of date, Openspot ignores what it prints.
- Print a value that comes from data with a helper, so that it can't add a line or a block: `openspot_kv`,
  `openspot_row` or `esc` in a shell, and `openspot.frame` in JavaScript. `openspot check spots` warns of a line with no `=`,
  of a key that shows twice in a block where only a list repeats, and of a key that the root or a kind doesn't take. An
  item can hold keys of its own, which Openspot sends back as `item.<key>` when it's picked.
- Openspot reads `ESC ] 9;4;1;<percent>` as `progress` and `ESC ] 9;<text>` as a toast, and removes other escape codes.
- A read that prints the same frame as the one that shows, with only a root and items, changes nothing, so Openspot skips
  it. A frame with another block, or over 256 KB, is drawn again.

## Blocks

A block is one thing on the sheet or the card: words, a number, a switch, an item of a list.

```ini
frame=
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

text=home
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
  Ids must be unique in one frame. An id is never `show`, `open`, `drop` or `drag`.
- Each kind keeps its data in `value`. A kind that shows several values repeats it.

| Kind      | Shows                                                                                                           | Its own keys                                                         | Sends                  |
| --------- | --------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------- | ---------------------- |
| `text`    | Words, and a small mark: a bar from `value`, or with `max` a bar for each `value` line.                         | `value`, `max`                                                       |                        |
| `number`  | A big number, with its `title` under it. `display` shows instead of `value`, and its `unit` part draws faint.   | `value`, `display`, `unit`                                           |                        |
| `graph`   | One `value` from 0 to 1 is a ring in a square place and a bar in a wide one. More values are bars, newest last. | `value`, and `max` for bars                                          |                        |
| `picture` | An image that fills its place.                                                                                  | `icon`                                                               |                        |
| `view`    | The SwiftUI view the manifest names (see [Views](#views)).                                                      | any key the view reads                                               |                        |
| `switch`  | A switch, or with `type=tick` a round tick before its words, for a thing to do.                                 | `value`: `true` or `false`, `type`                                   | `<id> true` or `false` |
| `field`   | A text field, or another input with a `type`.                                                                   | `value`, `type`, `placeholder`, `required`, `readonly`, `min`, `max`, `recording` | `<id> <value>`         |
| `choice`  | A menu of the `option` blocks after it, a list when it covers two lines or more, or swatches of `color` lines.  | `color`, `value`, `type`                                             | `<id> <option id>`     |
| `option`  | One option of the `choice` right before it.                                                                     | `title`, `icon`                                                      |                        |
| `button`  | A button, or an action (see [Buttons and actions](#buttons-and-actions)).                                       | `shortcut`, `confirm`, `close`, `look`, `form`, `scope`              | `<id>`                 |
| `section` | A title over the blocks after it, or over the items after it when the layout doesn't place it.                  |                                                                      |                        |
| `repeat`  | The place of the items (see [Items](#items)).                                                                   | `grid` lines                                                         |                        |

- A field's `type`: none for one line of text, `multiline` for several lines, `slider` from `min` to `max` (0 to 100 by
  default), which sends a whole number when the user lets go, and `hotkey` for a hotkey that a press records.
- A `hotkey` field shows as keycaps.
- A `hotkey` field records a key in Openspot when the user presses Return on it or clicks it, and when a new frame of
  the spot gives it `recording=true`. A frame that shows again, such as on a step back, records nothing.
- A `hotkey` field with a key gives the focus to the part after it.
- While a field records, every key goes to it. Esc stops the recording and brings back the key it had. A key that makes a shortcut ends the recording, sends
  `<id> <key>`, and moves the focus past the field.
- While a sheet with a `hotkey` field shows, Openspot's own keys are off, so only a press of a button saves a key, and a
  key that nothing on the sheet takes does nothing.
- The line under the keycaps comes from Openspot: whether the key is free, what macOS or another spot does with it, or
  which app took it.
- `type=search` makes a field the search field of the items (see [Items](#items)).
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

- Each `grid=` line of the root is one line of the sheet. Each word is one cell: the id of a block, `.` for an empty
  cell, or `-` for a divider across the line.
- The words of a line set the columns. A block fills the rectangle of cells that its id covers, and each id must cover a
  rectangle. A smaller block inside a bigger one sits on top of it, at the edge it touches.
- A `view`, a list, a chart, an image or a `multiline` field takes the free height of the sheet. `grow=false` keeps it
  at the height of its grid lines, and the sheet is as tall as its lines.
- `grid.<size>=` lines lay out the card at one size: `small`, `wide`, `square`, `strip` or `large`, and `grid.bar=`
  lines lay out the menu bar (see [Places](#places)). The user chooses the size of each card. A block that only a card
  layout places shows only on the card.
- A card layout can have more lines than the card has room for. A size with no layout uses the layout of the next
  smaller size. A spot with no card layout shows the default card (see [The card](#the-card)).
- With no `grid=` line, the layout is a search field over the items: each block that isn't a button is an item (see
  [Items](#items)).

## Buttons and actions

A button is a verb. If the layout places it, the sheet draws it. If not, it's an **action** in the ⌘K menu. See
[Add buttons](GUIDE.md#add-buttons) for an example.

- An action sends `<spot> <id> <item id>` while an item is selected, and `<spot> <id>` when none is.
- `scope` says when the ⌘K menu shows an action: `scope=item`, the default, only while an item is selected, and
  `scope=spot` always.
- A command of the manifest with `offers = ["actions"]` shows in the ⌘K menu of every card, under the spot's name, while no item
  is selected. Its press sends `<spot> <id> <card spot id>`. It isn't a command of the spot, so it gets no hotkey.
- A command whose ID is the ID of an offered command, a dot and a name, such as `[commands."change.draw"]` after
  `[commands.change]`, shows in the submenu of that action and fits the same cards. It takes no `offers`. → or a press
  opens the submenu, and ← goes back. A search finds its actions too.
- A filter after `actions`, a comma list, names the cards it fits by where their spot comes from: `mine`, a spot in the
  user's folder or a file of it that doesn't load; `core`, a spot that comes with Openspot and can be turned off; and
  `builtin`, a spot of Openspot itself, such as Settings. With no filter, it fits every card.

```toml
title = "Stars"

[commands.star]
title = "Star"
offers = ["actions"]
```

```sh
#!/bin/sh
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
- A press of a button or an action closes the panel. `close=false` keeps it open, such as for Delete or Star.
  `confirm` asks for a second press.
- A button `shortcut` is a letter, a digit, `return`, `backspace` or `,`, after `cmd+`, `shift+`, both or neither, such as
  `cmd+shift+n`, or `escape` alone. The user gives a command of the
  manifest its hotkey in the spot's [Settings](#settings).
- An action needs a `title`. `openspot check spots` reports an action with no title, or with a shortcut it can't use.
- `shortcut=escape` presses the button instead of closing the sheet, like a Cancel button.
- A placed button with a `shortcut` shows its key at its end, such as `⏎` or `Esc`.
- Return presses the button with `shortcut=return`; Space presses the part that has the focus, as Return does on a
  part with no such button.
- In a ⌘K menu of more than 5 rows, a field searches them, so only a `shortcut` with `cmd` works there.
- Return on an item runs the action `open`. `button=open` gives it a `title`, and `close=false` keeps the panel open after
  a pick.
- A button with `form=true` asks for values first. Its call runs once with empty stdin, and prints a `title` in its root
  and one `field`, `choice` or `switch` for each value. Then the same call runs again with the values on stdin.
- A form with only one `choice` shows its options as items under the search field. Return or a click sends one.
- With `type=multiple`, a choice picks several options. A checkmark marks each option in a `value` line. Return sends the
  option of its item, and `⇧⌘A` sends each option without a checkmark. The spot keeps the picks and prints the form again.
- A form can print itself again, such as with a `title` that says what's wrong. Then it stays open.
- When the call with the values runs `openspot select <item id>`, that item is selected after the sheet reads again, such
  as the item that the form made.

## Items

Items are a list that the user searches and picks from. See [Show a list](GUIDE.md#show-a-list) for an example.

```ini
text=milk
title=Milk
detail=2 left
icon=cart

switch=sync
title=Sync
value=true
close=false

field=key
type=hotkey
title=Open the list
close=false
```

An item is any block that the layout doesn't place, except a `button`, which is an action, and a `section`, which
titles the items after it. Each item draws as one line of the list:

- A `text`, and any other kind, draws its `icon`, `title`, `detail` and `tone`. `value=true` marks it with a checkmark,
  and more than one `value` line draws a bar for each, up to `max`. A pick sends `<spot> open <id>`.
- A `switch` draws a switch at its end, on while `value=true`. A pick sends `<spot> <id> true` or `false`.
- A `field` with `type=hotkey` shows its key from `value`. A pick records a new key and sends `<spot> <id> <key>`.
  `shake=true` lets a shake of the pointer, or a tap of one modifier, be the key.

| Key             | Meaning                                                                                        |
| --------------- | ---------------------------------------------------------------------------------------------- |
| `title`         | The first line. By default, the id.                                                            |
| `detail`        | The line under the title.                                                                      |
| `icon`          | The icon.                                                                                      |
| `tone`          | A dot of its colour on the icon.                                                               |
| `value`         | `true` draws a checkmark at the end. More than one line draws a bar for each, oldest first, in the colour of `tone`; `-` is a bar with no value. |
| `max`           | The value of a full bar. By default, the largest `value`.                                      |
| `parent`        | Where the item sits in its spot. The main search shows `<spot> › <parent>`.                    |
| `keywords`      | Words that find the item but don't show, split by commas.                                      |
| `pin`           | `top` or `bottom`: the item stays above or under the items that scroll, even in a search.      |
| `hides`         | The id of an action that this item doesn't offer. One line for each action.                    |
| `file`          | The file the item stands for. See [Files out](#files-out).                                     |
| `open.title`    | What Return does on this item, in place of the `title` of `button=open`.                       |
| `route`         | A route that a pick opens at once, in place of `<spot> open <id>`, with `route.title` and `route.replace`. See [Pages](#pages). |
| `close`         | `false` keeps the panel open after a pick of this item, or a key it records.                   |
| `shake`         | `true` on a `hotkey` field: a shake or a tap of one modifier can be its key.                   |

- A pick of an item closes the panel. `close=false` keeps it open, such as for a switch.
- Items go into the `repeat` that the layout places. With no `repeat`, they go under the blocks that the layout places.
  A frame has one `repeat`.
- With no `grid=` line, the sheet is a search field over the items. With a `grid=` line, it has a search field only
  when it prints a `field` with `type=search`, which shows at the top of the sheet.
- Openspot searches the items itself, and puts recent picks first. `recents=false` in the root turns that off.
- With `filter=spot` on the search field, each change of the search text asks the spot, and the spot prints the items
  that match. Each call gets `event=sheet.text` and the search text as `search=<text>` on stdin. `sheet.text` in `on` does
  the same for a sheet with no search field.
- `⌘↓` selects the last item, and `⌘↑` the first.
- A `repeat` has its own `grid=` lines, in which each word is the place of one item. The layout repeats down for as long
  as there are items. Items take the places in the order each word first shows.

```ini
repeat=photos
grid=a a b c
grid=a a d e
```

- To show more than one line, give the item an action, or draw it with a `view` that the layout places.

### Pages

A page is a sheet of a spot that shows one of its routes, such as the detail of an item, and a flow is the row of sheets
that the person went through. A route is the id of a page, such as `photo/12`. A spot opens its own routes and takes its
own sheets off. See [Open an item as a page](GUIDE.md#open-an-item-as-a-page) for an example.

| Key                   | Where                  | Does                                                                                 |
| --------------------- | ---------------------- | ------------------------------------------------------------------------------------ |
| `pages=<pattern>`     | the manifest           | The routes that the spot may show, such as `["text:*"]`.                             |
| `route=<route>`       | an item                | A pick opens that route at once, with no call.                                       |
| `route.title=<words>` | an item                | The title of the route's sheet, which its edge names. By default, the item's title.  |
| `route.replace=true`  | an item                | The route's sheet takes the place of the one that shows, so going back skips it.     |

A press moves the flow while it runs, such as after a form saves, with `openspot route`:

```sh
openspot route push photo/12 --title Beach
openspot route back
openspot route back --root
openspot route close
```

- `route push` shows a route of the spot over the sheet that shows. `--title` names its edge, and `--replace` takes the
  place of the sheet that shows, so going back skips it.
- `route back` takes the spot's sheet off, as Esc does. On its first sheet, that goes back to whoever pushed it, or to
  the grid. `--root` goes back to the spot's first sheet.
- `route close` takes each sheet of the spot off in one motion, back to the sheet that pushed the spot, or to the grid.
- Each call of a page, a show or a press, gets the page's route as `route=` on stdin. The first sheet of a spot gets none.
- A spot moves only its own routes, and only while its sheet shows. A move of another spot's sheet does nothing.
- A read never moves the flow: `openspot route` fails in a read.
- A route must match a `pages=` line of the spot that shows it, where `*` stands for any text. A spot with no
  sheet gets the call `<spot> open <route>` instead of a push.
- A spot takes off only its own sheets. It never takes off another spot's sheet and never closes the panel.
- The panel keeps the last 20 sheets. `⌘[` or a swipe to the right goes back, `⌘]` or a swipe to the left goes forward, Esc
  and `route back` take the sheet off so that nothing waits ahead, and `⌘Esc` goes back to the grid. A line left of the sheet
  stands for each sheet behind it, and a line right of it for each sheet ahead. A sheet
  that comes back shows what it last showed at once, and reads again.
- `openspot spot open <id>` starts a new flow on a spot. `openspot spot push <id> [page] [--replace] [--title <words>]` and
  `openspot spot pop <id> [--all]` move the flow that shows, as `openspot route` does. From a terminal, `openspot route` moves the
  sheet that shows, whatever its spot.

## The root

The root is the block of a frame that starts with `frame=`. It holds the layout of the frame and the words of the card,
and Openspot doesn't draw it.

```ini
frame=
title=Wi-Fi
detail=Home
grid=wifi

switch=wifi
value=true
```

- `frame=<route>` starts it. The route can be empty, as in `frame=`.
- Its layout keys: `grid=` and `grid.<size>=` lines, `title`, `detail` and `active` for the card, and `recents`.
- `progress=<0 to 1>` shows progress. With it, `title` and `detail` show only while the call runs.
- `shown=true` puts the card of a spot of the app on the grid, and `shown=false` takes it off. Openspot skips it in
  the frame of any other spot.
- `call=<n>` and `end=<n>` mark the calls of a staying spot (see [Modes](#modes)), in the root or in a block of their own.
- The root can come anywhere in the frame. Openspot skips and reports a second root.
- A block that starts with another key of the root, such as `title=`, is not a root. Openspot skips it as a block of an
  unknown kind.
- A frame holds no effect. A command does each one from the call, the same way as in a terminal: `openspot toast <words>`,
  `open <url>`, `openspot select <item>` and `openspot route`. See [The openspot command](#the-openspot-command).

## The card

The card stands for the spot on the grid. Use it to show one value at a glance, such as free disk space.

```ini
frame=
detail=Home
grid.wide=free

text=free
title=256 GB free
```

- Without `grid.<size>=` lines, a spot shows the default card: its icon, title and detail, and an arrow when Return
  opens its sheet.
- The **value** of the card is the one `text`, `number`, `graph`, `switch` or slider among the blocks that a layout
  places, or else the one among the items. The menu bar shows a value the same way, from its `grid.bar=` lines (see
  [Places](#places)).
- `active=true` in the root shows on the card that the spot's thing is on, and `active=false` that it is off.
- When a frame holds only one `switch` or one slider, the card draws it, and a press of the card changes it. A card
  that is a switch is active while the switch is on.
- A press on the card outside a control does what Return does (see [The keys of a spot](#the-keys-of-a-spot)). A press
  with `⌘` opens the spot's [Settings](#settings).

## Events

An event makes Openspot ask a spot what to show. The manifest lists the events where that is safe in `on`. See
[Respond to the Mac](GUIDE.md#respond-to-the-mac) for an example.

- An event is a word `<noun>.<verb>`. It can carry a value. The table gives the value of each event Openspot raises, and
  `openspot event emit` gives the value of any other.
- Each item of `on` names one event. Text after a space is a filter: a regular expression that the event's value must
  match.
- Only an event with a value takes a filter: `search.text`, `app.front`, `app.update`, or an event that a spot emits. A
  filter on any other event is an error. `sheet.text` takes none either, because the spot answers every search of its
  sheet.
- The sheet asks its spot each time it opens, with `sheet.open`, whether `on` lists it or not.
- Each `show` gets the event as `event=` on stdin, and its value as `event.value=`.
- Openspot measures the load once for all the spots that list `system.load`, and only while one of their places shows.

```toml
title = "Load"
on = ["system.load"]
```

```sh
#!/bin/sh
. "$OPENSPOT_SH"
load=$(value event.value)
printf 'frame=\ngrid.bar=load\n\ntext=load\ntitle=%s\n' "${load:-cpu=0 memory=0}"
```

| Event              | When Openspot raises it                                                   | Value         |
| ------------------ | ------------------------------------------------------------------------- | ------------- |
| `sheet.open`       | When the spot's sheet opens.                                              |               |
| `panel.open`       | Each time the panel opens, and once when the app starts.                  |               |
| `clock.<seconds>`  | Every that many seconds while a place of the spot shows, and when the Mac wakes. |        |
| `search.text`      | At each change of the main search text.                                   | the text      |
| `sheet.text`       | At each change of the sheet's search text, and when the sheet opens.      | the text      |
| `clipboard.change` | When the clipboard changes.                                               |               |
| `app.front`        | When another app comes to the front.                                      | its bundle ID |
| `app.update`       | When Openspot has downloaded an update.                                   | its version   |
| `app.launch`       | Once when Openspot starts.                                                |               |
| `screen.wake`      | When the screen wakes.                                                    |               |
| `system.load`      | Every 5 seconds while a place of the spot shows.                          | `cpu=<percent> memory=<percent>` |
| `power.change`     | When the Mac moves to another power source, or its battery gains or loses a percent. | `ac`, `battery` or `ups` |
| `disk.mount`       | When a disk or a volume mounts.                                           | its path      |
| `device.connect`   | When a USB device connects. A Bluetooth device raises no event.           | its name      |

- Openspot also asks a spot for these reasons, which aren't events:
  - `spot.change`: after a call that printed nothing;
  - `spot.want`: when a place starts to show a spot whose events haven't come yet, such as a card of a spot with only
    `power.change` in `on`.
- `openspot event emit <event> [value]` raises an event, from a spot or a terminal. If Openspot isn't running, it starts
  first.
- A spot must list each event it raises in `emits`, such as `emits=music.track`. `openspot check spots` reports an `on` event
  that neither Openspot nor any spot raises.
- A read must not raise the event that caused it. `openspot check spots` warns of a spot whose `on` and `emits` share an event.
- Openspot asks a spot only while one of its places shows: its sheet, its float or window, the menu bar, or its card on
  the grid while the panel is open (see [Places](#places)). A `panel.open` spot is asked at each open of the panel.
- `app.update` and `app.launch` ask each spot that lists them, whether a place shows it or not.
- A read must be safe at each event its manifest lists. Only you can make sure of that. A spot has one read at a time.

## The calls

A call asks a spot to do one thing. It works like a CGI call: arguments and a message on stdin go in, and a frame comes
out.

| Call                               | When                                                                      |
| ---------------------------------- | ------------------------------------------------------------------------- |
| `<spot> show`                      | An event that its manifest lists, or an open of its sheet.                |
| `<spot> open <item id>`            | A pick of an item.                                                        |
| `<spot> <id> [item id] [value]`    | A change or a press of a block, such as a pick of a `switch` item.        |
| `<spot> drop <path> [path]...`     | A drop of files on its card.                                              |
| `<spot> drag <item id> [item id]...` | A drag of items that stand for files out of its sheet.                  |
| `<spot> <command>`                 | A press of the hotkey the user gave a command.                            |
| `<spot> <command>`                 | A [slash command](#slash-commands), with `search=<text>` on stdin.        |

- `show` asks what to show. `open`, `drop` and `drag` are default ids. A block can't use any of the four, but a button
  can use `open`.
- A new default id reaches only a spot that asks for it.
- A drop on a card waits for the card's running call. A drop on a card whose Return opens the sheet opens it, and the
  call can select the new item with `openspot select`.
- A spot's hotkeys run one at a time, in order, and never stop a call. A staying spot gets each press at once, in
  order, so a second press can end the call of the first, while fewer than 8 calls of its hotkeys are open. Openspot
  drops a press past that with a toast. Only the user gives a command a hotkey.

Each call has three parts:

- **Arguments:** `<id> [item] [value]`: the id, its item, then its values, so that `case "$1"` handles each call. A value
  over 64 KB goes only on stdin, as `input.value=`.
- **Variables:** `OPENSPOT_ID`, the spot's id, `OPENSPOT_DATA`, a
  folder for its files that one spot folder shares, `OPENSPOT_SH`, the shell helper, `PATH`, and `LC_ALL`, which is
  `en_US.UTF-8`, so each tool reads text as UTF-8 and writes numbers and dates one way on every Mac. A command that
  handles raw bytes or needs byte order sets `LC_ALL=C` for itself, such as `LC_ALL=C sort`, since `sed` and `tr` fail
  on text that isn't UTF-8, and `sort` and `[a-z]` follow the locale. `PATH` holds the
  `openspot` command first, then the paths of the user, then `/opt/homebrew/bin`, `/usr/local/bin`, `/usr/bin`, `/bin`,
  `/usr/sbin` and `/sbin`. Five more are for the spots that ship inside Openspot: `OPENSPOT_CONFIG`, the folder of the config,
  `OPENSPOT_SPOTS`, the spots folder when it isn't `spots` in that folder, and for the sheet that changes a spot,
  `OPENSPOT_EDIT`, the id of that spot, `OPENSPOT_EDIT_FILE`, its file when the user owns it, and
  `OPENSPOT_EDIT_FAILURE`, its last failure.
- **Stdin:** the message, one block of what the call knows. Each key has a prefix that says where it comes from:

| Key              | Holds                                                                                                 |
| ---------------- | ----------------------------------------------------------------------------------------------------- |
| `event=`         | On a `show`, the event that asked, such as `sheet.open` (see [Events](#events)).                       |
| `event.value=`   | The value of that event, such as the search text of `search.text`.                                     |
| `route=`         | The page that shows (see [Pages](#pages)). The first sheet of a spot has none.                         |
| `search=`        | The search text.                                                                                       |
| `search.alt=`    | Each other text the user may have meant, such as the same keys in another keyboard layout.             |
| `input.<id>=`    | Each input of the sheet or of a form, such as a field. A value that isn't an input comes as `input.value=`. |
| `setting.<key>=` | Each setting of the manifest that has a value, a secret too (see [Settings](#settings)).               |
| `item.<key>=`    | On an action or a pick of an item that holds a key of its own, such as `meeting=`, each key of the item. |

```ini
event=sheet.text
event.value=milk
route=photo/12
search=milk
search.alt=ьшдл
input.title=Groceries
setting.city=Paris
```

- The calls of a form get no `item.` keys.
- Each process that the spot starts inherits its stdin, with each setting and the keys of the item, unless the spot reads
  it first or closes it for that process, such as `curl "$url" </dev/null`.

The shell helper reads and writes values for you:

| Function                                    | Does                                                                                                  |
| ------------------------------------------- | ----------------------------------------------------------------------------------------------------- |
| `esc <text>`                                | Prints text as a value.                                                                               |
| `value <key>`                               | Prints each value of the key from stdin, one per line, in order.                                      |
| `openspot_value <key> <text>`               | Prints each value of the key from a text, such as the frame that an `openspot` call prints.           |
| `openspot_input`                            | Prints the stdin of the call as it came.                                                              |
| `openspot_kv <key> <value>`                 | Prints one line, with its value escaped.                                                              |
| `openspot_row <id> <title> [detail] [icon]` | Prints one item, a `text` block.                                                                      |
| `openspot_rows [kind]`                      | Prints an item, a `text` block or one of that kind, for each tab-separated line of stdin: id, title, detail, icon. |
| `openspot_serve <function> "$@"`            | Runs the function with the three parts of each call, in each mode.                                    |
| `openspot_keep <file> [text]`               | Keeps the text, or all of stdin, in the file as a whole, so a reader never gets half of it.           |
| `openspot_paste <text>`                     | Pastes the text into the front app, then puts back the text that the clipboard held, or clears it.    |

- Loading the helper reads all of stdin, except in a staying spot, and keeps it in memory. So read the stdin of a call
  with `value` or `openspot_input`, not with `cat` or `read`: the function of `openspot_serve` gets an empty stdin in
  each mode, and so does each process it starts.
- `openspot_keep` makes the folder of the file. When it can't write, it fails and the old file stays as it was.
- `openspot_paste` needs `clipboard` in `uses`. It fails when the paste fails, and puts the clipboard back first. It puts
  back the text that the clipboard held. A clipboard that held a picture, a file or nothing is cleared, so the pasted
  text never stays on it.

```toml
title = "Echo"
```

```sh
#!/bin/sh
. "$OPENSPOT_SH"
printf 'frame=\ngrid=note\ngrid=echo\n\nfield=note\ntitle=Note\n\ntext=echo\n'
openspot_kv title "$(value input.note)"
```

## Slash commands

A slash command runs a command or a spot that has a `placeholder`, with the text that the user typed, in one Return.
A `placeholder` says that a command takes text. A plain search finds spots; `/` runs one with text.

```text
/translate hello world     Return opens Translate, and its show gets search=hello world
buy milk /notes            Return runs notes add, with search=buy milk on stdin
```

- In the main search, `/` at the start of a word, with a letter after it, lists the commands of the manifest, the `scope=spot`
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
| A spot with a `placeholder` and no command | Its sheet opens, and the show of the sheet gets it |

- The first frame of the call decides what shows. A frame with fields is a form, as for a `form=true` button, and Return
  in it sends the values to the same call. Other blocks open the spot's sheet with them. A frame with nothing to show,
  such as only a `toast`, or the end of the call closes the panel, unless the `button` has `close=false`.
- A command with `confirm` isn't listed, since a slash command doesn't ask twice.

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

- A `show` has 10 seconds to print its first frame or end. Other calls have no time limit.
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

The user decides where a spot shows: on the grid, in the menu bar, in a float or in a window. A spot says what each
place draws with a layout for its size. See [Show a value on a card](GUIDE.md#show-a-value-on-a-card) for an example.

```ini
frame=
grid.small=free
grid.wide=free total
grid.bar=free

text=free
title=256 GB

text=total
title=of 1 TB
```

| Size                                        | Where                                                                 |
| ------------------------------------------- | --------------------------------------------------------------------- |
| `small`, `wide`, `square`, `strip`, `large` | A card on the grid. The user chooses its size.                        |
| `bar`                                       | The menu bar, next to the clock. A click opens the sheet under it.    |

- The sheet, a float and a window draw the `grid=` lines, as in [Layouts](#layouts).
- A size with no layout uses the layout of the next smaller size. A card with none shows the icon, title and detail
  (see [The card](#the-card)). A spot in the menu bar with no `grid.bar=` lines shows its icon there.
- The menu bar shows the value of the blocks that `grid.bar=` places: a `text`, a `number` or a `graph`. A read that
  prints nothing hides it until the next read.
- The user puts any spot on the grid, in the menu bar, in a float or in a window, from its [Settings](#settings) and
  from Edit Spots. The manifest names no place, and a spot can't claim a hotkey or a place.
- A float shows the spot in a small window at the pointer, which a hotkey or a shake of the pointer opens, and which
  stays while the user works in other apps. The spot never learns where it shows.
- A window opens the sheet in a normal window, from the card, the main search or `openspot spot open`. The user moves,
  resizes and closes it, and Openspot shows in the Dock while it's open. Esc closes it too, and a view that fills it
  should still give a way out, such as a Done button.
- A spot with a `clock` or a command starts off the grid, so that a new spot doesn't fill the panel.

### The main search

`offers = ["search"]` shows the spot's items in the main search, and `search.text` in `on` makes it answer what the user
types.

- `search` in `offers` needs `panel.open`, `sheet.open` or a `clock` in `on`. With only `sheet.open`, Openspot reads
  the items when it loads the spots, as it starts or after a spot changes, after each change of the config, and at each
  open of the sheet. A panel open doesn't read them. Openspot ranks the items by the user's picks.
- `search.text <pattern>` in `on` makes a spot answer the main search. Openspot asks it at each change of a text that the
  pattern matches, with no pause. A newer text stops the older call. The answer should be fast.
- Its items show first in the main search until the newest text has an answer, and go at once when the pattern no longer
  matches. A pick of an item sends `<spot> open <item id>`.
- With `answers = "last"`, its items show under the other results instead, such as an item that offers to make a spot of
  the typed words. A search that finds only such items counts as a search that found nothing.
- A spot whose only event is `search.text` has no card.
- An answer can be one card instead of items: its root has `grid.large=` or `grid.strip=` lines, and the card's value
  has a `value`. A pick of the card sends `<spot> open <value>`.
- `openspot calc solve <words>...` prints the answer to a sum, a conversion or a date as an item.
- `offers = ["actions"]` on a command, not at the top, shows that command in the ⌘K menu of every card (see
  [Buttons and actions](#buttons-and-actions)).

## Modes

Openspot starts a spot for each call, unless its manifest says otherwise.

- `mode = "once"` starts a process for each call.
- `mode = "stay"` keeps one process, which gets each call on stdin while one of its places shows (see [Events](#events)).
- `mode = "stay"` with `app.launch` in `on` keeps that process from the start of Openspot until it quits.
- A `.js` file that the manifest describes, with no execute permission, runs inside Openspot. A `.js` file that it
  doesn't describe can hold shared code. An executable `.js` file runs as a process, like any other spot.

### A JavaScript spot

```toml
title = "Hello"
on = ["sheet.open"]
```

```js
function main(args, env, input) {
  if (args[0] === "show")
    return openspot.frame({
      text: "hi",
      title: `Hello from ${openspot.value("event", input)}`,
    });
  return "";
}
```

- The file defines `main(args, env, input)`, which gets the three parts of a call and returns the text of a frame. `input`
  is the message, the same text that stdin holds.
- `openspot.value("setting.city", input)` returns the value of a key from a text, as `openspot_value` does: each value on
  a line of its own, or `""` when there's none.
- `openspot.call(["calc", "solve", "2+2"])` runs the `openspot` command and returns `{ stdout, code }`. A second argument
  gives its stdin.
- `openspot.frame(object)` writes an object, or a list of objects, as blocks. An object whose first key is `frame`, such as
  `{ frame: "", title: "Hi" }`, is the root.
- It has no files, no network and no process of its own. It runs one call at a time, on a thread of its own.
- Openspot waits 2 ms for its frame in the same keystroke, and shows a later frame on the next one.
- A call has 10 seconds. After that it fails as a slow read, and the spot answers its next call.

### A staying spot

```toml
title = "Relay"
mode = "stay"
on = ["app.launch", "panel.open"]
```

```sh
#!/bin/sh
. "$OPENSPOT_SH"
main() {
  case "$1" in
    show) printf 'frame=\ngrid=message\ngrid=send\n\nfield=message\ntitle=Message\n\nbutton=send\ntitle=Send\nshortcut=cmd+return\n' ;;
    send) openspot toast "Sent: $(value input.message)" ;;
  esac
}
openspot_serve main "$@"
```

Openspot writes each call to the spot's stdin as one block, then a blank line. `call=<n>` numbers the call, an `arg`
line gives each argument, and the lines of its message follow, as a spot that runs once gets them on stdin.

```ini
call=4
arg=send
input.message=Hello
setting.city=Paris
```

- A staying spot is one process that talks both ways over stdin and stdout. Each call goes to the running process, and
  no call starts a second copy.
- `openspot_serve main "$@"` runs `main` with the three parts of each call, and prints `call=<n>` before its output and
  `end=<n>` after it. The same `main` works in every mode.
- The spot can print frames at any time. It must end each call with `end=<n>`. A frame of only `call=<n>` starts the
  output of that call, so the next frame replaces what shows.
- A second press of a running call sends the block `stop=<n>`. The call ends 2 seconds later, unless the spot prints a
  frame for it first, such as a frame of only `call=<n>`; then the call runs on to its `end`. That is how a spot keeps a
  window open and brings it to the front at a second press. A form, and a call stopped by a newer value of its block,
  stop at once. `openspot_serve` reads stdin only between calls, so it can't see a stop while `main` runs. A newer
  search text sends `stop=<n>` for the read of the older text, so only the newest answer shows. A read after the first gets `stop=<n>` after 10 seconds, and fails
  as a slow read.
- With `mode = "stay"`, the process runs while one of its places shows, or while a call waits for its `end`. When none
  shows any more, Openspot closes its stdin, and the spot must end, with every process it started. After 2 seconds its
  process group gets the terminate signal, and 2 seconds later the kill signal.
- After 3 failures in one minute, Openspot tells the user, and starts the spot again only when its file changes. Keep
  what must survive in `OPENSPOT_DATA`.

### A Swift spot

A spot can be a Swift program. Openspot builds it once, and runs the built program at each call. See
[Write a spot in Swift](GUIDE.md#write-a-spot-in-swift) for an example.

```toml
title = "Cups today"
on = ["sheet.open"]
source = ["cups.swift"]
```

```swift
#!/usr/bin/env swift
print("text=cups\ntitle=\(cups) cups")
```

```swift
let cups = 3
```

- A Swift file with `#!/usr/bin/env swift` on its first line is a spot, when the manifest describes it.
- Each item of `source` names one more Swift file, or a folder whose Swift files it takes, next to the spot. Openspot
  builds them into one program with the spot's file, which holds the code that runs first. Only a Swift spot takes
  `source`, and a source is a plain path inside the spot's folder, such as `model` or
  `model/cups.swift`: no `.`, no `..`, and no `/` at its start or end.
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

```toml
title = "Cups today"
on = ["panel.open", "sheet.open"]
view = "cups.swift"
```

```sh
#!/bin/sh
printf 'frame=\ngrid=cups\n\nview=cups\ntitle=3\nvalue=1\nvalue=0\nvalue=2\n'
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

- `view = "<file>"` in the manifest names a SwiftUI file next to the spot. A `view=<id>` block draws it in its place.
- The spot and its view must be in a folder of their own, such as `cups.spot/cups.sh` and `cups.spot/cups.swift`.
- The file declares `struct SpotView: View` with `let spot: SpotInput`, and has no top-level code.

| Member              | Gives                                                                 |
| ------------------- | --------------------------------------------------------------------- |
| `spot["key"]`       | The last value of a key of its block, or nil.                         |
| `spot.all("key")`   | Each value of a key that repeats.                                     |
| `spot.size`         | The size of its place.                                                |
| `spot.card`         | The name of its card's size, such as `wide`, or nil off a whole card. |
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
| `spot.loop(...)`    | A shape that moves in a loop, played by macOS. See the note below.     |
| `spot.cornerButton` | The round button on the rim of a card, by its id and an action.       |
| `spot.columnGap`    | The gap between the columns of the grid.                              |
| `spot.rowGap`       | The gap between the rows of the grid.                                 |
| `spot.columns`      | How many columns a window holds.                                      |
| `spot.tipDelay`     | How long the pointer rests on a control before its tip shows.         |
| `spot.theme`        | The values of the theme, by role. See the table below.                |
| `spot.rows`         | Each `row` block of the frame, in a sheet or a window, in order.      |
| `spot.isShown`      | Whether its place shows now. It's false while the panel is hidden.    |
| `spot.selection`    | The id of the selected row of the sheet, or nil.                      |
| `spot.close()`      | Closes the sheet, the float or the window of its spot.                |

`spot.theme` gives the values of the theme (see [Change the look of Openspot](GUIDE.md#change-the-look-of-openspot)) in
five groups. Each colour and strength is the one of the appearance that shows.

| Member              | Gives                                                                                                  |
| ------------------- | ------------------------------------------------------------------------------------------------------ |
| `spot.theme.color`  | The colours `ink`, `solid`, `onSolid`, `accent`, `good`, `warn` and `bad`, and the strengths `secondary`, `fill`, `selected` and `track`. |
| `spot.theme.space`  | `padding`, `columnGap`, `rowGap`, `listRow`, `listRowGap`, `glyph`, `cell`, the side of a grid cell, and `gridWidth`. |
| `spot.theme.radius` | `card`, `media`, and `inner`, the corner of a part that sits `padding` inside the view's place.         |
| `spot.theme.font`   | The fonts `title`, `body`, `detail` and `input`.                                                       |
| `spot.theme.motion` | `press`, the time of a press in seconds, and `pressBounce`, its bounce.                                |

- `SpotMetric(spot, value:, detail:, mark:, onFill:)` draws a big number with its detail and an SF Symbol `mark`, laid
  out for `spot.card` as the other cards lay out theirs, and for the size of its place off a card. It drops the detail
  when the line has no room for it, and keeps the mark. `onFill: true` draws it in white, over a colour that the view
  draws.
- The view fills its place, and the whole card when there's no card layout. It can't change the size of its place.
- In a window (see [Places](#places)), a sheet with one `view` block fills the window. `spot.card(id)` draws the card of
  any spot by the ID that `openspot store list` prints, as the store does. `spot.sheet(id)` draws its sheet with what its
  `sample.sh` prints (see [A spot](#a-spot)), and draws nothing for a spot with no sample.
- It gets the keys of its block in each frame. A new frame keeps its `@State`.
- On a card, the view only draws, and a press works as on any card. In a sheet, it takes clicks and keys, and
  `spot.send(value)` calls the spot with `<id> <value>`, as a field does. A newer send stops the call of the older one.
- Openspot compiles it when its card first shows, and again when the file changes. A view that doesn't compile shows its
  first error, and `openspot check spots` prints it.
- A shared spot carries the compiled view as `<name>.<hash>.view`, where the hash is the SHA-256 of Openspot's view
  code and the source. Openspot uses it instead of the source only while that hash matches.
- Each row of `spot.rows` has its `id`, `row["key"]` for the last value of a key and `row.all("key")` for each
  value, as the view's own block has. In a sheet, Openspot still draws the rows under the view. In a window that one
  view fills, only the view draws them. A card gets no rows. A `view` block takes no `row` key of its own, and
  `openspot check spots` reports one.
- `spot.close()` closes only the open sheet, the float or the window of the view's own spot. It does nothing on a card,
  in the sheet that `spot.sheet(id)` draws, and in a card that `spot.card(id)` draws. A view can call it from any thread.
- `spot.loop(period:fill:path:)` and `spot.loop(period:stroke:width:path:)` draw a shape that moves on its own, such
  as a wave. A fill takes one colour, or several for a gradient from top to bottom. `path` gives the shape at each
  time from 0 to `period` in a rect of the view's size, and the shape at `period` must equal the one at 0. Openspot
  draws it about ten times a second of the loop, and macOS plays it between those steps. Openspot draws it again only
  when the spot's values or the view's size change, so `path` reads nothing else. It plays only while `spot.isShown`
  is true, and a pause holds it where it is. A `TimelineView` or a timer that redraws the view on each frame slows
  Openspot instead.
- Openspot removes a view while its place is hidden, and builds it again at the next show, so its `@State` starts
  anew. A view that reads `spot.isShown` stays built instead, and must stop its timers and its motion while it's false.
- `openspot spot stats` counts each run of the `body` of `SpotView` and the time of that one `body` (see
  [Stats](#stats)). It doesn't time the bodies of the views inside it, which SwiftUI runs later.
- `SpotView` must not declare a method named `update()`: Openspot keeps that name, and SwiftUI would call it before
  each `body`.
- The view runs inside Openspot, so a crash quits Openspot. Do the work in the spot, and only draw in `body`.

## Files out

An item can stand for a file that the user drags into another app.

```toml
title = "Shelf"
icon = "tray.full"
drop = "*"
on = ["sheet.open"]
```

```sh
#!/bin/sh
. "$OPENSPOT_SH"
list="$OPENSPOT_DATA/files"
case "$1" in
  show)
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

- An item with `file=<path>` stands for that file. The user can drag it into any app that takes files. The path must start
  with `/`.
- The other app copies or moves the file. A read should leave out each file that no longer exists.
- When a drag ends in another app, Openspot sends `<spot> drag <item id>...`. A drag with no drop sends nothing. If the
  call prints nothing, Openspot asks the spot again.
- Dragging the icon in the head of the sheet drags every item that has a `file`.

## The openspot command

A spot asks the Mac and Openspot for things through one command, which works the same in a terminal.

- Each capability is `openspot <noun> <verb>`.
- A noun names its commands, its events and its use, such as `openspot clipboard copy`, `clipboard.change` and
  `clipboard` in `uses`.
- `openspot` reaches the Openspot app that it ships in, and within a spot, the app that ran the spot. `openspot --config <folder>
  <call>` reaches the Openspot that runs on that config folder instead. No variable changes where a call goes.
- A call that reads files or asks the Mac gives the same answer whether Openspot is running or not. A call that needs the
  running app starts it, and waits up to 10 seconds.
- Ctrl-C stops a call, and the stopped work changes nothing.
- `openspot help` lists each command, grouped by what it's for. `openspot help <noun>`, or `--help` after a noun or a
  verb, prints only its verbs, then the guide of a noun that has one, such as `screen` or `calendar`. `openspot help --json`
  prints each verb with its form, its effect and whether it needs the app.
- A call exits with code 0 when it's done, 1 when it failed, 2 when `openspot` doesn't take its words, and 3 when it
  needs the app and no app answered. Words that `openspot` doesn't take print the verbs of the noun they name, or the
  command they're closest to.
- A capability that can't answer prints `status=<word>`. A capability that keeps state keeps it in its own helper.
- `openspot translate text` prints `status=unknown` when it cannot tell the language of the text, `status=missing` when macOS
  has not downloaded a language, `status=unsupported` when it knows no way between the two, and `status=failed` for any
  other fault. `openspot calc solve` prints `status=offline` or `status=unavailable` for a currency with no rates.
- When macOS already has a command, such as `open`, use it. For the screen and the clipboard, use `openspot screen` and
  `openspot clipboard`, so that the user sees each use.
- These calls fail in a read, so that a read changes nothing and opens nothing:
  - calls that wait for the user: `color pick` and `folder pick`;
  - calls that capture the screen: `screen shot`, `screen record start` and `screen record stop`;
  - calls that change the Mac or the user's data: `window move`, `clipboard copy`, `clipboard paste`, `power lid-closed`, `calendar add`,
    `reminders add`, `reminders done`, `spot add`, `spot remove` and `spot delete`;
  - calls that change Openspot or its places: `app quit`, each call of `theme` but `theme list` and `theme open`, `update install`, and `setting set` of a key that Openspot
    keeps for the user (see [Settings](#settings));
  - calls that move the flow of sheets: `route push`, `route back` and `route close`;
  - calls that open a window or the panel: `spot open`, `spot choose`, `spot settings`, `spot edit`, `spot prompt`, `spot share`, `spot review`, `grid edit`, `setting change`, `theme open`,
    `update check`, `calendar show` and `reminders show`.
- `calendar add --dry-run` and `reminders add --dry-run` change nothing, so they work in a read. `toast` and `select`
  work in a read too.
- Within a spot, `toast`, `select` and `route` act for the call that ran them. When that call is out of date, since a
  newer value stopped it or its sheet closed, they do nothing and exit with code 0, as its frames do. From a terminal,
  they act on the sheet that shows.
- `openspot batch` runs one call for each line of stdin, and prints `---` after each. It stops at the first failure.
- Each call that lists or reports, such as `app status`, `power readings`, `account show`, `spot list`, `spot stats`, `store list`, `setting list` and
  `theme list`,
  prints blocks, the format of a frame. `--json` prints JSON.

The commands that try a spot are in [Try your spot](GUIDE.md#try-your-spot). The others:

| Command                                            | Does                                                                                            |
| -------------------------------------------------- | ----------------------------------------------------------------------------------------------- |
| `openspot guide [topic \| --topics]`               | Prints the guide, then this protocol. A topic prints one section or the page of a noun, such as `screen`, and `--topics` lists them. |
| `openspot version`                                 | Prints the version of Openspot, as `openspot --version` does.                                   |
| `openspot toast <words>...`                        | Shows a short message, even when the panel is closed.                                           |
| `openspot select <item>`                           | Selects an item of the spot's sheet once the spot's next frame shows.                           |
| `openspot route push <route> [--title <words>] [--replace]` | Shows a route of the spot over the sheet that shows. See [Pages](#pages).              |
| `openspot route back [--root]`                     | Goes back one sheet of the spot, or to its first sheet. See [Pages](#pages).                    |
| `openspot route close`                             | Takes each sheet of the spot off. See [Pages](#pages).                                          |
| `openspot spot open <id> [--select]`               | Opens the panel on a spot, as a new flow. See [Pages](#pages). `--select` only selects its card. |
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
| `openspot store list [--json]`                     | Prints each spot of the store and its step: `get`, `publish`, or `added` once you have it.      |
| `openspot store get <id>`                          | Gets a spot of the store: turns it on, or adds its package to your spots folder.                |
| `openspot store add <folder>`                      | Adds a folder that holds spot folders as a store, so the Store lists its spots. The folder's name is the store's name. |
| `openspot store remove <folder>`                   | Removes a store that `store add` added. The spots you got from it stay.                         |
| `openspot store folders [--json]`                  | Prints the built-in store Openspot, which holds the examples, then each store that `store add` added, with its name and whether its folder is found. |
| `openspot store publish <id>`                      | Publishes a spot of your spots folder to the store. It needs a `readme.md` beside its script. Only the Store spot can run it, so you publish from the Store spot. |
| `openspot playground open [file]`                  | Opens the Playground on a spot that you type or on a file.                                      |
| `openspot check sheet`                             | Reports the faults of a sheet on stdin.                                                         |
| `openspot render sheet [--view <file>] <file.png>` | Draws the sheet on stdin to a picture, with its view from a Swift file.                         |
| `openspot render card <size> <file.png>`           | Draws the card of the sheet on stdin at a size, such as `wide`, to a picture.                   |
| `openspot render spot <id> <file.png>`             | Draws the sheet of an installed spot, or with `--card <size>` its card, to a picture.           |
| `openspot render panel <file.png>`                 | Draws the panel with each installed spot on its grid.                                           |
| `openspot render store <file.png>`                 | Draws the window of the Store with each spot as its card.                                       |
| `openspot prompt new [words]...`                   | Prints a prompt that asks a coding agent to build a spot that does what the words say.          |
| `openspot prompt change <id> [words]...`           | Prints a prompt that asks a coding agent to change a spot as the words say, with what [Stats](#stats) counted of it over 14 days. With no words, its goal follows those counts. |
| `openspot prompt theme <name> [words]...`          | Prints a prompt that asks a coding agent to change a theme as the words say.                    |
| `openspot emoji list [--tone name]`                | Prints each emoji as an item, with its name in the language of the Mac.                         |
| `openspot symbols list`                            | Prints each symbol of the Character Viewer as an item.                                          |
| `openspot translate text [--from code] [--to code]` | Translates the text on stdin. `openspot translate languages` prints the languages it knows.     |
| `openspot theme <verb>`                            | Lists the themes, and uses, makes and changes one: `list`, `use`, `new`, `duplicate`, `rename`, `delete`, `open` and `reload`. See [Change the look of Openspot](GUIDE.md#change-the-look-of-openspot). |
| `openspot account show [--json]`                   | Prints the public facts of the account that signs what you publish. See [Trust](#trust).        |

### Settings

A setting keeps a choice of the user. Each spot has its own Settings, a sheet apart from its own rows, which `⌘` Return
on its card, a press of the card with `⌘`, or **Settings** in its ⌘K menu opens. Return does the spot's main act, and
`⌘` Return sets it up. See [Let the user choose a setting](GUIDE.md#let-the-user-choose-a-setting) for an example.

- The Settings of a spot list each thing the user can change about it, in this order: first its keys, **Open**, the
  hotkey of each command in its manifest, and **Float**; then what the spot itself does, each setting, set or not, and
  each value it keeps that no setting names, such as a look; and last its places, **Show in the menu bar** and **Open in
  a window**, which every spot has.
- Each shortcut is a `field` item with `type=hotkey` (see [Items](#items)). Return on it records a key, and `⌘⌫` removes the key.
- Openspot makes the Settings sheet, and it grows from the spot's card. Its rows never show in the spot's own sheet.
- The Settings spot of Openspot holds only the settings of the app: its keys, Careful mode, Slow
  motion, Open at login and the `openspot` command. The Themes spot of Openspot changes its look.
- A `[settings.<key>]` table in the manifest names a setting. Return on it runs the action with the same id, which can answer with a
  form. `⌘⌫` removes the value.
- Each call gets the value of each setting on stdin, as `setting.<key>=<value>`, such as `setting.folder=`, so a spot
  reads its settings with no `openspot` call. A spot never gets the settings of another spot this way.
- `type = "secret"` on a setting keeps a value such as a key of a service. Return on its row asks for the value in
  Openspot's own form. A call gets it as any other setting, never in a variable or an argument.
  Settings show only that it is set, and Openspot hides it in the call log, the stats, a toast and a failure line.
- Openspot keeps a secret in the Keychain, under the spot's id and the field's key, never in the config. Only a
  `type=secret` field of that spot gets it, and it goes when the spot is removed. See [Trust](#trust).

```toml
title = "Weather"
on = ["sheet.open"]

[settings.city]

[settings.token]
type = "secret"
```

```sh
#!/bin/sh
. "$OPENSPOT_SH"
city=$(value setting.city)
printf 'text=city\ntitle=%s\n' "${city:-Paris}"
if [ -n "$(value setting.token)" ]; then printf 'text=token\ntitle=Signed in\n'; fi
```

- A secret has 8 characters or more. Openspot hides only the exact value, so a part of it or another form of it, such
  as its base64, still shows.
- `openspot spot run` in Terminal and `openspot check spots` pass no settings.
- `openspot setting get <key>` prints the value, or nothing, and `•••` for a secret that is set. `openspot setting set <key> [value]` keeps the value, or
  removes it when there's no value. In a terminal, `--spot <id>` names the spot.
- Keep a choice of the user in a setting. Keep what the spot makes, such as a cache, in `OPENSPOT_DATA`.
- Openspot keeps some keys for the user, and a setting can't use them:
  - of any spot: `icon`, the path of a picture that draws in place of the manifest's icon, which Change Icon in the menu
    of a card keeps; `enabled` and `menubar`, `true` or `false`, and `open`, `float` and `key.<command>`, a hotkey such
    as `ctrl+option+k`, `shake`, or one modifier alone, such as `option`, which a tap of that key presses, or no value
    to remove it. The key of `open` does what a press of the spot's card does, from any app;
  - of the spot `openspot`, which is the app: `login`, `link`, `careful` and `slow`, `true` or `false`, and `panel-key`
    and `fix-key`. `slow` runs each motion of the panel ten times slower until the app quits.
- Each of these keys needs the use of the call that does the work (see [Trust](#trust)).

### Stats

Openspot counts what each spot cost and used, so that the user can see it.

```sh
openspot spot stats --days 7
```

- Openspot keeps one file for each day, for 90 days. Today's numbers are live.
- An act is something the user did with a spot: they opened its sheet, picked a row, pressed, set or toggled something,
  or ran one of its actions. A read is never an act, and acts on one spot within 2 seconds count as one.
- `--days N` adds up the last N days. `--spot <id>` shows one spot.
- `--by version` prints a row for each version of a spot, the oldest first, so you can compare a spot before and after
  a change. A version is a short hash that changes each time a file of the spot is written, replaced or touched.
  The version `-` holds the counts with no known version, such as those kept before versions, and sorts first.
- `--openmetrics` prints each counter as [OpenMetrics](https://openmetrics.io) text, labelled by `spot`, and by
  `version` with `--by version`, so that any tool for metrics can read it.
- It prints an item, a `text=<id>` block, for each spot, the most CPU first, then a `use=<n>` block for each call that needs a
  use, the newest first, then a `search=<text>` block for each search that found nothing. `--json` prints the days.

| Item key             | Meaning                                                               |
| -------------------- | --------------------------------------------------------------------- |
| `title`, `detail`    | The name of the spot, and its numbers in words.                       |
| `version`, `since`   | With `--by version`, the version of the item, and when it was first counted. |
| `runs`, `failures`   | The calls that ended, and those that failed.                          |
| `cpu`, `seconds`     | The CPU seconds of its processes, and the wall time of its calls.     |
| `read`, `written`    | The bytes its processes read and wrote.                               |
| `wakeups`            | The times its processes woke the CPU.                                 |
| `acts`, `last`       | The user's acts, and the time of the last one.                        |
| `days`               | The acts of each day, oldest first. `-` for a day with no count.      |
| `reads.<reason>`     | The reads for one reason, such as `reads.sheet.open=3` or `reads.clock=40`. |
| `hidden.cpu`, `hidden.wakeups` | The part of `cpu` and `wakeups` spent while the panel was hidden. |
| `p50`, `p95`         | The seconds within which half, and 95 in 100, of its reads and searches first answered. |
| `memory`             | The most memory its own process held at once, in bytes, not counting the processes it starts. |
| `seen`               | The days that hold a count of the spot.                               |
| `runs.by.<id>`       | The part of `runs` that the spot `<id>` started with `openspot spot run`. |
| `ran.<id>`           | The runs of the spot `<id>` that this spot started with `openspot spot run`. |
| `failures.<kind>`    | The failures of one kind: `timeout`, `exit` or `output`.              |
| `failed`             | The time of its last failure.                                         |
| `call.<noun>.<verb>` | The count of one call that needs a use, such as `call.screen.shot=2`. |
| `network`            | `declared` when its manifest names `network`.                         |
| `bodies`, `body`     | The runs of the `body` of its `SpotView`, and their seconds in all.   |
| `fault`, `tone`      | Its last error, with `tone=bad`.                                      |

- A `search` block holds a search of the panel that found nothing, folded to lower case, and its `count`. A search of
  3 letters or more counts when you clear it or hide the panel with no pick, by the longest text that found nothing.
  A day keeps 50.
- A `use` block holds `time`, `spot`, `call`, such as `app.quit`, and `declared`. Only a call that the manifest doesn't
  declare is logged, so `declared` is `false`; `call.<noun>.<verb>` counts each call.

## Trust

A spot runs with the user's rights. Openspot shows what a spot can do, and what it did.

```toml
title = "Coffee"
uses = ["app"]
```

```sh
#!/bin/sh
openspot app quit
```

- Openspot asks nothing in daily use. It shows what a spot can do when the user adds or updates it, and shows each use
  after it happens.
- Openspot knows which spot makes each call of `openspot` by the link it gives each process of the spot on file descriptor 11, not
  from the variables of the process. Each process that the spot starts inherits it, so leave fd 11 open. An app that the spot
  opens doesn't get it, and the link ends with the spot's process. A process of the spot that closed fd 11 is still known by
  the process group that Openspot started it in. A call that runs in a process of its own, such as one that the running app hands
  back, runs with the rights of the spot's process and nothing more.
  Only the user's own processes can reach the API.
- No spot and no Terminal reads a secret (see [Settings](#settings)): `setting get` and `setting list` print `•••` for
  it, to its own spot too, and `setting set` of it fails. Only Openspot's own form changes it.
- `uses` names what a spot uses. Openspot doesn't load a spot with an unknown use.

| Use         | The calls that need it                                                                                                                                          |
| ----------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `app`       | `app quit`, each call of `theme` but `theme list`, `update check`, `update install`, and `setting set` of `menubar`, `open`, `float`, `key.<command>` or of the spot `openspot`                                |
| `spots`     | `spot add`, `spot remove`, `spot settings`, `spot edit`, `spot prompt`, `spot share`, `spot delete`, `spot new`, `spot run`, `spot log`, `setting list`, `setting set` of `enabled`, and `setting get`, `set` or `change` of another spot |
| `screen`    | `screen sources`, `screen shot`, `screen record`, `window frame`, `window move` and `color pick`                                                                |
| `clipboard` | `clipboard copy`, `clipboard paste` and `clipboard read`                                                                                                        |
| `calendar`  | each call of `calendar` and `reminders`                                                                                                                         |
| `power`     | `power lid-closed`                                                                                                                                              |
| `network`   | No call. The spot reaches the network.                                                                                                                          |
| `files`     | No call. The spot writes outside its data folder.                                                                                                               |
| `account`   | `store publish`. Only a spot that ships inside Openspot can have it.                                                                                            |

- A call that needs a use the manifest doesn't name still runs, and shows one toast for each spot, use and day.
  `openspot check spots` can't report it, because only a run shows it.
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
  `uses` names `network`, and writes only to its data folder and the temp folders unless it names `files`. With `screen`, it
  can also write to the Desktop, Movies and the screenshots folder. In Careful mode, a call that needs a use the manifest
  doesn't name fails.
- Without Careful mode, the data folder is no boundary.
- A spot folder can hold `releases.jsonl`, the signed releases of the spot. Openspot writes it when the user shares or
  publishes the spot, and refuses a shared spot whose files don't match its last release. A spot reads nothing from it.
- `openspot account show` tells any spot the public facts: whether an account is signed in, its `npub`, the `handle` it was
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
spot raises the major number, and adds a manifest key `protocol`. A spot without that key is version 1.

## How to extend

An old spot never sees a word it didn't ask for. An old app skips a word of a frame that it doesn't know, and doesn't
load a spot whose manifest has a key that it doesn't know.

| To add               | Add                                                              |
| -------------------- | ---------------------------------------------------------------- |
| A thing that happens | an event `<noun>.<verb>`                                         |
| A place to show      | a size of a layout, `grid.<size>=`                               |
| A thing to draw      | a kind `<kind>=`, which an old app skips and reports             |
| A detail of a kind   | a key, or a `type` value                                         |
| A power of the Mac   | a noun: `openspot <noun> <verb>`, its events and its `uses` word |
| A complex look       | nothing: a `view` of the spot                                    |
