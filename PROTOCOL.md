# Openspot protocol

`2.0` `draft`

This is the contract between a spot and Openspot. The overview teaches its five words. Then
[Print blocks](#print-blocks) is enough for most spots, [Lay out and react](#lay-out-and-react) makes a spot answer the
user, and [Advanced](#advanced) covers the rest, so you can stop as soon as your spot does what you need.
[Reference](#reference) holds the exact tables. To learn by example, start with the [guide](GUIDE.md). What
the user chooses, such as the keys and places of a spot, is in [What the user chooses](GUIDE.md#what-the-user-chooses),
and what Openspot shows the user about a spot is in [Trust](TRUST.md).

## Overview

A spot answers calls with frames, and makes each change through `openspot` commands. What it prints flows one way, into
what the user sees, and what the user does next starts it again.

```text
  ┌──────────────────────── the user presses, or the Mac changes ◄───────────────────────┐
  ▼                                                                                      │
event ──► call ──► spot ──► frame ──► Openspot draws it in each place ──► the user sees it
                    │
                    └──► openspot <noun> <verb>      each change, such as a toast or a copy
```

- **Spot:** a folder that Openspot runs, a script and its manifest, `spot.toml`, which says when to call it. See [A spot](#a-spot).
- **Call:** one run of the spot. Its event is why it came, and its mode is how it runs. See [The calls](#the-calls).
- **Frame:** everything a call shows at one time, its blocks and its layout. See [Frames](#frames).
- **Block:** one thing in a frame, such as a text, a number or a switch. See [Show things with blocks](#show-things-with-blocks).
- **Command:** `openspot <noun> <verb>`, the one way a spot changes anything. See [The openspot command](#the-openspot-command).

## Principles

These rules hold everywhere, and the details follow from them.

- **A spot gives data, and Openspot draws it.** A block says what a thing is, and its place chooses its look, such as a
  ring or a bar for a [number](#numbers). Openspot chooses every width, gap and colour.
- **A frame describes, and a command changes.** Printing a frame never changes the Mac, and a `show` call runs no
  command that changes anything.
- **The user chooses the places and the keys.** The spot lays out each place it cares about.
- **A spot keeps no state between calls.** Openspot asks it again at each event it lists, and each show replaces the
  last, so a call can end at any time.
- **Each meaning has one form.** Every call is `<id> [item] [value]`, and a key such as `title` means the same on every
  block.
- **Text first.** A spot is any program that prints lines of `key=value`. A [view](#views) is only for a look that
  blocks can't give.

# Print blocks

At its simplest, a spot is a manifest with a title and a script that prints blocks, and Openspot lays them out. This is
the minimum a spot needs.

## A spot

A spot is a folder that Openspot runs: a manifest that names it, and a script that prints what to show. See
[Your first spot](GUIDE.md#your-first-spot).

- A **spot folder** is a folder `<name>.spot` in the spots folder, such as `coffee.spot`. It holds `spot.toml`, the
  [manifest](#the-manifest), its scripts, a `readme.md`, a `sample.sh` and any file they need. Its scripts share one
  data folder, and the folder is shared as one unit of at most 25 MB.
- The id of a script is the name of its folder, such as `coffee`, and a script with another name adds it, such as
  `home/lights` for `home.spot/lights.sh`. A script that `spot.toml` doesn't describe can hold shared code.
- `sample.sh` prints what the spot would show, with made-up data. Publish ships its output as `sample.frame`, which the
  store of spots shows, and where a click runs nothing.
- A line of `readme.md` that holds only a Markdown image of a file in the folder shows that PNG, JPEG, MOV or MP4. An
  `https` picture is fetched once, with no cookies, and an `https` video shows as a link.
- Openspot moves a loose script into a spot folder of its name, and writes a `spot.toml` with the script's title.
- An agent can do anything the user does, with `openspot spot run <id> <call>` and `openspot event emit`. A spot can't
  tell who called it.

## The calls

A call works like a CGI call: arguments and the message on stdin go in, and frames come out. The message is one block
of what the call knows. See [Show a list](GUIDE.md#show-a-list) and [Ask for values](GUIDE.md#ask-for-values).

A **press** is a click or a key that the user aims at a spot, such as Return on an item or a command's hotkey. Openspot
makes a call at each of these:

| Call                                 | When                                                                  |
| ------------------------------------ | --------------------------------------------------------------------- |
| `<spot> show`                        | An [event](#events) that its manifest lists, or an open of its sheet. |
| `<spot> open <item id>`              | A press of an item.                                                   |
| `<spot> <id> [item id] [value]`      | A change or a press of a block, such as a switch or a button.         |
| `<spot> drop <path> [path]...`       | A drop of files on its card.                                          |
| `<spot> drag <item id> [item id]...` | A drag of items that stand for files out of its sheet.                |
| `<spot> <command>`                   | A press of a command's hotkey, or a [slash command](#slash-commands). |
| `<spot> due <timer id>`              | A [timer](#act-at-a-time) of the spot comes due.                      |

- **Arguments:** `<id> [item] [value]`, so that `case "$1"` handles each call. `show`, `open`, `drop` and `drag` are
  Openspot's own ids: no block takes them, except a button `open`. In a spot that uses `timer`, `due` is one too. A value over 64 KB comes only as `input.value=`.
- **Variables:** `OPENSPOT_ID`, the spot's id; `OPENSPOT_DATA`, the data folder of its spot folder; `OPENSPOT_SH`, the
  shell helper; `PATH`, with the `openspot` command first, then the user's paths, `/opt/homebrew/bin`,
  `/usr/local/bin`, `/usr/bin`, `/bin`, `/usr/sbin` and `/sbin`; and `LC_ALL=en_US.UTF-8`, so each tool reads text as
  UTF-8 on every Mac. A command that handles raw bytes sets `LC_ALL=C` for itself.
- **Stdin:** the message, whose keys are in [The message](#the-message). Each process
  that the spot starts inherits it, unless the spot reads it first or closes it for that process, such as
  `curl "$url" </dev/null`.

The shell helper, `. "$OPENSPOT_SH"`, reads stdin once and keeps it, and writes values for you. After it loads, read
stdin with `value` or `openspot_input`, not `cat`: the function of `openspot_serve` gets an empty stdin.

| Function                                     | Does                                                                                            |
| -------------------------------------------- | ----------------------------------------------------------------------------------------------- |
| `esc <text>`                                 | Prints text as a value.                                                                         |
| `value <key>`                                | Prints each value of the key from stdin, one per line, in order.                                |
| `openspot_value <key> <text>`                | Prints each value of the key from a text, such as what an `openspot` command printed.           |
| `openspot_input`                             | Prints the stdin of the call as it came.                                                        |
| `openspot_kv <key> <value>`                  | Prints one line, with its value escaped.                                                        |
| `openspot_item <id> <title> [detail] [icon]` | Prints one item, a `text` block.                                                                |
| `openspot_items [kind]`                      | Prints an item for each tab-separated line of stdin: id, title, detail, icon.                   |
| `openspot_rows <key>...`                     | Prints a tab-separated line for each block of stdin, with the value of each key, such as what an `openspot` command printed. |
| `openspot_serve <function> "$@"`             | Runs the function with the arguments of each call, in each [mode](#modes).                      |
| `openspot_keep <file> [text]`                | Keeps the text, or stdin, in the file as a whole, or fails and keeps the old file.              |
| `openspot_paste <text>`                      | Pastes the text into the front app and puts the clipboard back. It needs `clipboard` in `uses`. |

## Frames

A frame is everything a call shows at one time. A call can print several, so a spot can show progress, then the result,
or change one block while the rest stays.

- Openspot draws each frame as soon as it arrives. [The format](#the-format) says where a frame ends.
- The first frame of a call replaces what shows, and so does a later frame with a `frame=` line. A later frame with no
  `frame=` line changes only the blocks it prints: a block whose id already shows replaces that block, and a new id joins
  the end.
- If a show prints nothing, the spot shows nothing. If another call prints nothing, Openspot asks the spot again.
  Openspot ignores what an out-of-date call prints.
- Print a value that comes from data with `openspot_kv`, `openspot_item`, `esc` or `openspot.frame`, so that it can't
  add a line or a block.
- Openspot removes escape codes, such as colours and terminal progress, from the output. Show progress with
  `progress=` and a toast with `openspot toast`.

### The root

The root is the block that starts with `frame=`. It holds the layout of the frame and the words of the card, and isn't
drawn.

- `frame=<route>` starts it. The route is the name of the sheet the frame is for, and can be empty; see
  [Pages](#pages).
- It takes `grid=` and `grid.<size>=` lines, `title`, `detail` and `active` for the card, and `recents`.
- `progress=<0 to 1>` shows progress, and then `title` and `detail` show only on the running call.
- `call=<n>` and `end=<n>`, here or in a block of their own, mark each call of a [staying spot](#a-staying-spot), one
  process that answers many calls.
- The root can come anywhere in the frame. Openspot skips and reports a second root. A frame with only a root changes
  no block.

## Show things with blocks

Print one block for each thing the spot shows: words, a number, a switch, an item of a list. See
[Your first spot](GUIDE.md#your-first-spot).

- The first key of a block is its kind, and its value is the block's id. Anything with its own title or icon is a block.
- The id names the block in the layout, the call it sends and what moves when it changes, and is unique in a
  frame. Each kind keeps its data in `value`, and a kind that shows several values repeats it.
- With no layout, a `text` or a `switch` is a row of the list, and a `button` is an **action**, a row of the ⌘K menu.
  [Layouts](#layouts) places them.
- [Blocks](#blocks) lists each kind, its own keys and the keys that every kind takes.

# Lay out and react

Here you place blocks where you want them, show a spot outside its sheet, and answer the user and the Mac.

## Layouts

A layout places the blocks of a frame. Write it the way you write CSS grid areas.

```text
grid=title title title      title
grid=wifi  wifi  nets       wifi          nets
grid=all   .     nets       all   empty   nets
grid=-     -     -          ──────────────────── a divider
grid=note  note  note       note
```

- Each `grid=` line of the root is one line of the sheet. Each word is a cell: the id of a block, `.` for an empty
  cell, or `-` for a divider. The words of a line set the columns.
- A block fills the rectangle of cells that its id covers. A smaller block inside a bigger one sits on top of it, at
  the edge it touches.
- A `view`, a list, a `number` with several values, an image or a `multiline` field takes the free height of the
  sheet, unless it has `grow=false`. With no `grid=` line, the layout is a search field over the items.

## Places

A place is where a frame shows. Lay out each place the spot cares about with `grid.<size>=` lines, where the size names
a place in the table below. See [Show a value on a card](GUIDE.md#show-a-value-on-a-card).

| Size                                        | Where                                                              |
| ------------------------------------------- | ------------------------------------------------------------------ |
| `small`, `wide`, `square`, `strip`, `large` | A card in the panel. The user chooses its size.                    |
| `bar`                                       | The menu bar, next to the clock. A click opens the sheet under it. |

- A card shows the spot in the panel, which Openspot's hotkey opens, and the spot's sheet fills the panel when the user
  opens the spot. A spot can also show in the menu bar, in a float, a small window at the pointer, and in a window, a normal window that
  holds its sheet.
- The user chooses the places, and the spot only adds a layout for the ones it cares about.
- The sheet, a float and a window draw the `grid=` lines. A size with no layout uses the next smaller one. A card with
  none shows the icon, title and detail, and the menu bar the icon. The menu bar shows a `text` or a `number` by its own rule, in
  [The menu bar](#the-menu-bar), and a show that prints nothing hides it until the next show.

### The card

The card stands for the spot in the panel.

- Its **value** is the one `text`, `number`, `switch` or slider that its layout places, or else the one among the
  items.
- `active=true` in the root shows that the spot's thing is on.
- A card whose frame holds only one switch or slider draws it, and a press changes it. Any other press does what Return
  does; see [The keys of a spot](GUIDE.md#the-keys-of-a-spot).

### The menu bar

The menu bar shows the block that `grid.bar` places, small, beside the clock.

- A `number` with one value and a `max` is a small ring with its value. A `number` with several values is its last 8
  bars with its value.
- A `text` with a `tone` and no `icon` is a dot of its tone and its title. Any other `text` is its title.
- With no block in `grid.bar`, the items are counted by their tone. A `switch` or slider in `grid.bar` hides it.
- `look` doesn't apply here.

## Numbers

A number shows a value, such as the battery, or a series, such as the use of the CPU over the last minutes. Print the
data, and Openspot chooses how to draw it for each place.

```ini
number=battery
value=84
max=100
unit=%
```

- `value` is the number, and each more `value` line adds a point of a series, oldest first. The last point is the one
  that shows, and `-` is a point with no value, drawn as a gap. `max` is the value of a full ring or bar, and by default the largest point.
- `unit` follows the value, as in `84%` or `12 kg`, and `display` shows instead of the value, as in `display=–`.
- A series is its last value over its bars in an area of two rows or more and two columns or more.
- Otherwise, with `max`, one value or the last point of a series is a ring in an area as tall as it's wide, and a bar
  in a wider one. A series with no `max` is a bar of its points, and any other number is big text.
- `chart=ring` or `chart=bar` sets the drawing whatever the area. Only a number takes `chart`.

## Show again when something happens

Events, such as the panel opening or the battery changing, make Openspot ask a spot what to show. See
[Respond to the Mac](GUIDE.md#respond-to-the-mac).

- List in `on` each event at which a show is safe and useful, such as `on = ["system.load"]`, and the show gets
  `event=system.load` and `event.value=cpu=12 memory=40`. [Events](#events) lists each one.
- Text after a space in `on` is a filter, a regular expression that the value must match. Any event with a value
  takes one, and `search.text` needs one.
- The sheet asks its spot at each open, unless it asked the spot less than 5 seconds ago. With `sheet.open` in `on`,
  it asks again even then. Openspot asks a spot only while one of its
  places shows, except at `app.launch` and `app.update`. A spot has one show at a time.
- Openspot also asks after a call that printed nothing, with `spot.change`, and with `spot.want` when a place starts to
  show a spot whose events haven't come yet.
- `openspot event emit <event> [value]` raises an event `<noun>.<verb>`, and starts Openspot first. A spot lists each
  event it raises in `emits`, and a show doesn't raise the event that caused it. `openspot check spots` reports an `on`
  event that nothing raises.

## Buttons and actions

A button is a verb, such as Forget, that the sheet draws where the layout places it. See
[Add buttons](GUIDE.md#add-buttons) and [Ask for values](GUIDE.md#ask-for-values).

- An action sends `<spot> <id> <item id>` while an item is selected, and `<spot> <id>` when none is. `scope=item`, the
  default, shows it only while an item is selected, and `scope=spot` always. An action needs a `title`.
- Each press closes the panel, on a block, an item, a command or an [offered action](#offered-actions), unless it has
  `close=false`. `confirm` asks for a second press. Return on an item runs the action `open`, and `button=open` gives it
  a `title`.
- `shortcut` is a letter, a digit, `return`, `backspace` or `,`, after `cmd+`, `shift+`, both or neither, or `escape`
  alone, which presses the button instead of closing the sheet. In a ⌘K menu of 3 rows or more, only a `shortcut`
  with `cmd` works, since a field searches the rows.
- `form=true` asks for values first: the call runs once with empty stdin and prints a `title` in its root and a
  `field`, `choice` or `switch` for each value, then runs again with the values. A form that prints itself again,
  such as with what's wrong, stays open. In a choice with `type=multiple`, a `value` line marks each chosen option.

## The openspot command

A spot asks the Mac and Openspot for everything it does through `openspot <noun> <verb>`, which works the same in a
terminal. [The openspot commands](app/Help/commands.md), which `openspot guide commands` prints, lists each one.

- A noun names its commands, its events and its use, such as `openspot clipboard copy`, `clipboard.change` and
  `clipboard` in `uses`. When macOS already has a command, such as `open <url>`, use it.
- `openspot toast <words>` shows the words for a moment, `openspot select <item>` selects an item once the next frame
  shows, and `openspot route` moves between [sheets](#pages). They work for the call that ran them, and do nothing when
  it's out of date. From a terminal, they work on the sheet that shows.
- A show changes nothing and opens nothing, so a command that waits for the user, captures the screen, changes the Mac,
  Openspot or the sheets that show, or opens a window fails in it; see
  [the commands that fail in a show](app/Help/commands.md#the-calls-that-fail-in-a-show).
- A command exits 0 when it's done, 1 when it failed, 2 when `openspot` doesn't take its words, and 3 when Openspot
  didn't answer. A command that has no answer prints `status=<word>`. A list or a report prints blocks, or JSON with
  `--json`.

## Items

Items are the list that the user searches and presses. See [Show a list](GUIDE.md#show-a-list).

| Key          | Meaning                                                                                         |
| ------------ | ----------------------------------------------------------------------------------------------- |
| `title`      | The first line. By default, the id.                                                             |
| `detail`     | The line under the title.                                                                       |
| `icon`       | The icon.                                                                                       |
| `tone`       | A dot of its colour on the icon.                                                                |
| `value`      | `true` draws a checkmark.                                                                       |
| `parent`     | Where the item sits in its spot. The [main search](#the-main-search) shows `<spot> › <parent>`. |
| `keywords`   | Words that find the item but don't show, split by commas.                                       |
| `pin`        | `top` or `bottom`: the item stays above or under the items that scroll, even in a search.       |
| `hides`      | The id of an action that this item doesn't offer. One line for each action.                     |
| `file`       | The file the item stands for. See [Files out](#files-out).                                      |
| `open.title` | What Return does on this item, in place of the `title` of `button=open`.                        |
| `route`      | A [route](#pages) that a press opens at once, in place of `<spot> open <id>`.                   |
| `close`      | `false` keeps the panel open after a press of this item, or a key it records.                   |
| `shake`      | `true` on a `hotkey` field: a shake or a tap of one modifier can be its key.                    |

- A block that the layout doesn't place is an item, unless it's a `button`, which is an action, a `choice`, which the
  sheet draws, or a `section`, which titles the items after it.
- A `number` item shows its value on the right of its title, a ring of it with `max`, or the bars of a series, as in
  [Numbers](#numbers).
- A press of a text sends `<spot> open <id>`, of a switch `<spot> <id> true` or `false`, and of a `hotkey` field
  records a key. A press closes the panel, unless the item has `close=false`. An item can hold keys of its own, such as
  `meeting=42`, which come back as `item.<key>=`.
- Items go into the `repeat` that the layout places, or with none, under the placed blocks. A frame has one `repeat`,
  and its own `grid=` lines give each item a place, repeated down for as long as there are items.
- With a `grid=` line, only a `field` with `type=search` adds a search field over the items. Openspot searches the
  items and puts the items pressed most recently first, unless the root has `recents=false`.
- With `sheet.text` in `on`, each change of the text asks the spot with
  `event=sheet.text` and `search=<text>`, and the spot prints the items that match.

### The main search

The main search, the panel's own search field, lists items from every spot. See
[Answer the main search](GUIDE.md#answer-the-main-search).

- `offers = ["search"]` adds the spot's items to it, and `search.text` in `on` makes the spot answer what the user
  types.
- With no `panel.open` or clock in `on`, Openspot asks for the items when it loads the spots and at each open of the
  sheet.
- `search.text <pattern>` asks the spot at each change of a text that matches, and a newer text stops the older call.
  Its items show first, or under the others with `answers = "last"`. A spot whose only event is `search.text` has no card.
- A spot can print one card instead of items: its root has `grid.large=` or `grid.strip=` lines, and a press sends
  `<spot> open <value>`.

## Settings

A setting keeps a choice of the user, such as a city or a token. See
[Let the user choose a setting](GUIDE.md#let-the-user-choose-a-setting).

- Each call gets each setting that has a value on stdin, such as `setting.city=Paris`, so the spot reads it with no
  `openspot` call.
- Return on a setting in the spot's Settings runs the call with the same id, which can answer with a form.
- `type = "secret"` keeps a value of 8 characters or more, such as a token. Openspot asks for it in its own form, gives
  it on stdin only, and hides the exact value in the call log, the stats, a toast and a failure line.
- `openspot setting get <key>` prints a value, or `•••` for a secret. `openspot setting set <key> [value]` keeps a
  value, or removes it. A setting can't use a key that Openspot keeps for the user; see
  [The Settings of a spot](GUIDE.md#the-settings-of-a-spot). Keep what the spot makes, such as a cache, in `OPENSPOT_DATA`.

# Advanced

These rules are for a spot that needs more than one sheet, a process that stays, an answer in the same keystroke, a look
of its own, or a place in another spot's ⌘K menu.

## Pages

A spot can show more than one sheet, each named by its route, such as `photo/12` for the detail of an item. See
[Open an item as a page](GUIDE.md#open-an-item-as-a-page).

| Key                   | Where        | Does                                                                   |
| --------------------- | ------------ | ---------------------------------------------------------------------- |
| `pages=<pattern>`     | the manifest | The routes that the spot may show, such as `["text:*"]`.               |
| `route=<route>`       | an item      | A press opens that route at once, with no call.                        |
| `route.title=<words>` | an item      | The title of the route's sheet. By default, the item's title.          |
| `route.replace=true`  | an item      | The route's sheet replaces the one that shows, so going back skips it. |

- A press moves between sheets while its call runs, such as after a form saves, with `openspot route`. `route push`
  shows a route over the sheet that shows, and `--replace` replaces it. `route back` takes the spot's sheet off, as Esc
  does, or with `--root` goes back to its first sheet. `route close` takes each sheet of the spot off.
- Each call of a sheet with a route gets it as `route=`. A route matches a `pages=` line, where `*` stands for any
  text. A spot with no sheet, one with commands and no event, gets the call `<spot> open <route>`
  instead.
- A spot moves only its own routes, while its sheet shows. It never takes off another spot's sheet and never closes the
  panel, and a show never moves between sheets.

## Modes

A mode says how Openspot runs the program of a spot.

- Openspot starts a process for each call, `mode = "once"`, unless the manifest says otherwise.
- `mode = "stay"` keeps one process, which gets each call on stdin while one of its places shows, or from launch to
  quit with `app.launch` in `on`.
- A `.js` file with no execute permission runs inside Openspot.

### A staying spot

Use a staying spot to keep a window, a device or a stream open across calls. It gets each call on its stdin and answers
on its stdout.

```toml
title = "Relay"
mode = "stay"
```

```sh
#!/bin/sh
. "$OPENSPOT_SH"
main() {
  case "$1" in
    show) printf 'frame=\ngrid=send\n\nbutton=send\ntitle=Send\n' ;;
    send) openspot toast Sent ;;
  esac
}
openspot_serve main "$@"
```

- Write a staying spot with `openspot_serve`, as here: it runs `main` with the arguments of each call, so the same
  `main` works in every mode.
- A second press of a running call stops it. The call ends 2 seconds later, unless the spot prints a frame for it
  first; then it runs on to its end, which is how a spot brings its window to the front. A form, and a call that a
  newer value or search text stopped, stop at once.
- A show after the first is stopped after 10 seconds, and after 2 such slow shows Openspot ends the spot.
- When no place shows the spot and no call waits, Openspot closes its stdin. The spot ends with each process it
  started, or its group gets the terminate signal 2 seconds later, and the kill signal 2 seconds after that.
- After 3 failures in one minute, Openspot starts the spot again only when its file changes. Keep what must survive in
  `OPENSPOT_DATA`.

> **Note:** A program that doesn't use `openspot_serve` reads and writes the calls itself. Openspot writes each call to
> stdin as one block: `call=<n>`, an `arg` line for each argument, then the message. The program prints `call=<n>`
> before the output of each call and `end=<n>` after it, and a frame of only `call=<n>` starts the output of that call.
> A stop of a call comes as `stop=<n>`.

### A JavaScript spot

A JavaScript spot runs inside Openspot, so it answers in the same keystroke. Use it for a spot that answers as the user
types; [Answer the main search](GUIDE.md#answer-the-main-search) shows one.

- `main(args, env, input)` gets the arguments, the variables and the message of a call, and returns the text of a
  frame.
- `openspot.value(key, text)` returns each value of a key, a line each, or `""`. `openspot.call(words, stdin)` runs the
  `openspot` command and returns `{ stdout, code }`. `openspot.frame(object)` writes objects as blocks, and an object
  whose first key is `frame` is the root.
- It has no files, no network and no process, and runs one call at a time. Openspot waits 2 ms for its frame, and
  shows a later one at the next keystroke. A call has 10 seconds.

### A Swift spot

A Swift spot is a program that Openspot builds once and runs at each call. Use it for work that a script does badly;
[Write a spot in Swift](GUIDE.md#write-a-spot-in-swift) shows one.

- A Swift file with `#!/usr/bin/env swift` on its first line is a spot, when the manifest describes it. Each item of
  `source` names one more Swift file, or a folder of them, as a plain path in the spot folder: no `.`, no `..`, and no
  `/` at its start or end.
- Openspot needs the Command Line Tools, and builds again when a file changes. A spot with no `source` runs as a script
  until its build is done, and a failed build is the failure of each call until a file changes.
- A shared spot carries the program as `<name>.<hash>.program`, by the SHA-256 of its Swift files. A Mac with no tools
  runs it while the hash matches; see [The review before an add](TRUST.md#the-review-before-an-add).

## Views

Openspot draws a view where the layout puts its `view` block. Use it for a chart, a board or a look of your own;
[Draw your own view](GUIDE.md#draw-your-own-view) shows one.

- The file declares `struct SpotView: View` with `let spot: SpotInput`, with no top-level code and no method
  `update()`. A `view=<id>` block draws it in its place.

| Member                                          | Gives                                                                                                       |
| ----------------------------------------------- | ----------------------------------------------------------------------------------------------------------- |
| `spot["key"]`                                   | The last value of a key of its block, or nil. `spot.all("key")` gives each value.                           |
| `spot.size`, `spot.card`                        | The width and height of its area, and the name of its card's size, such as `wide`, or nil off a whole card. |
| `spot.inset`, `spot.corner`                     | The space a card keeps inside its edge, and its corner radius.                                              |
| `spot.ink`, `spot.secondary`, `spot.accent`     | The colour of words, the opacity of a second line, and the accent colour.                                   |
| `spot.font`                                     | The fonts of the cards: `title`, `detail`, `metric` and `value`.                                            |
| `spot.theme`                                    | The values of the theme; [Follow the theme in a view](GUIDE.md#follow-the-theme-in-a-view) lists them.      |
| `spot.send(v)`, `spot.answers`                  | Calls the spot with `<id> <v>`, as a field does, and changes at each answer, to end a busy state.           |
| `spot.card(id)`, `spot.cardSize(id)`            | The card of a spot, by the id that `openspot store list` prints, and its size.                              |
| `spot.sheet(id)`                                | The sheet of a spot from its `sample.sh`, where a click runs nothing.                                       |
| `spot.tip(text)`, `spot.tipDelay`               | A tip in the look of Openspot's own, to show on hover, after that delay.                                    |
| `spot.media(path)`                              | A PNG or JPEG picture, or a MOV or MP4 video, at its size or less.                                          |
| `spot.loop(...)`                                | A shape that moves in a loop, played by macOS.                                                              |
| `spot.cornerButton`                             | The round button on the rim of a card, by its id and an action.                                             |
| `spot.columnGap`, `spot.rowGap`, `spot.columns` | The gaps between cards, and how many columns of cards a window holds.                                       |
| `spot.items`, `spot.selection`                  | Each item of the frame, in a sheet or a window, and the id of the selected one.                             |
| `spot.isShown`                                  | Whether its place shows now. It's false while the panel is hidden.                                          |
| `spot.close()`                                  | Closes the sheet, the float or the window of its own spot.                                                  |

- The view fills its area, gets the keys of its block in each frame, and keeps its `@State`. On a card, it only draws.
  In a sheet, it takes clicks and keys. In a window, a sheet with one `view` block fills it and draws `spot.items`.
- `SpotMetric(spot, value:, detail:, mark:, onFill:)` draws a big number with its detail and an SF Symbol `mark`.
- `spot.loop(period:fill:path:)` and `spot.loop(period:stroke:width:path:)` draw a shape at each time from 0 to
  `period`, and the shape at `period` equals the one at 0. It plays only while `spot.isShown` is true. Never redraw at
  each screen refresh with a `TimelineView` or a timer.
- Openspot removes a view while its place is hidden, unless it reads `spot.isShown`, and then it stops its timers and
  its motion while that is false. It compiles the view at its first show and when the file changes, and a shared spot
  carries it as `<name>.<hash>.view`, used while the hash matches.
- The view runs inside Openspot, so a crash quits Openspot. Do the work in the spot, and only draw in `body`.
  [Stats](app/Help/stats.md) counts each run of its `body`.

## Files out

An item can stand for a file that the user drags into another app, and a card can take files dropped on it.

- `file=<path>` makes the item stand for that file, such as `file=/Users/me/Report.pdf`, and the path starts with `/`.
  A drag carries only the files that still exist. When a drag ends in another app, Openspot sends
  `<spot> drag <item id>...`.
- `drop` in the manifest names the files a card takes, and a drop sends `<spot> drop <path>...`. It waits for the
  card's running call, opens the sheet of a spot whose Return opens it, and the call can select the new item.

## Slash commands

A slash command runs a command or a spot that has a `placeholder`, with the text the user typed, in one Return. See
[Run a command with text](GUIDE.md#run-a-command-with-text).

- `/` at the start of a word, with a letter after it, lists the commands, the `scope=spot` buttons of a sheet and the
  spots with a `placeholder` whose name matches. `/` alone lists them all. A word that matches none stays text.
- The call gets the rest of the line, the words before and after the command, as `search=<text>`, with the arguments
  of a plain press. With no text, a command runs as its hotkey does, and a spot does what Return does on its card. A
  command with `confirm` isn't listed.
- A first frame with fields is a form, whose values go to the same call. Other blocks open the sheet. A frame with
  nothing to show, or the end of the call, closes the panel, unless the command has `close = false`.

## Offered actions

An offered action is a command of one spot that shows in the ⌘K menu of every card, so that it can work on any spot.

- A command with `offers = ["actions"]` shows in the ⌘K menu of every card, under the spot's name, and sends
  `<spot> <id> <card spot id>`. It closes the panel, unless it has `close = false`. A command
  `<offered id>.<name>`, such as `[commands."change.draw"]`, shows in its submenu. Origins after a space, such as
  `offers = ["actions mine, core"]`, fit only the cards of the user's spots (`mine`) or of the spots that come with
  Openspot (`core`).
- In a JavaScript spot, `when=<function>` on an offered button gets the card's spot id and its origin, and returns
  whether the action shows. `hotkey=<function>` returns the card's hotkey. The ⌘K menu waits 2 ms for them.

## Act at a time

A timer calls its spot back at a time the spot chose, such as the end of a snooze, even when the panel is closed.

```toml
title = "Stretch"
icon = "figure.walk"
on = ["sheet.open"]
uses = ["timer"]
```

```sh
#!/bin/sh
case "$1" in
  show) printf 'button=later\ntitle=Remind me in an hour\nscope=spot\n' ;;
  later) openspot timer add "$(date -u -v+1H +%Y-%m-%dT%H:%M:%SZ)" "Time to stretch" ;;
  due) openspot toast "$(sed -n 's/^event.value=//p')" ;;
esac
```

A press of Remind me in an hour adds a timer. An hour later, Openspot calls `stretch due <timer id>`, and the spot
shows the toast Time to stretch.

- `openspot timer add <time> [value]` takes an ISO 8601 time with its offset, such as `2026-11-20T08:00:00+01:00`, and
  prints the timer's id. A time that has passed comes due at once.
- At the time, Openspot calls `<spot> due <timer id>` with `event=timer.due`, `event.value=` the value, and
  `timer.late=` the seconds it came late, such as after the Mac slept or Openspot was quit. Openspot drops the timer as
  it calls, and draws nothing that the call prints.
- `openspot timer list` prints each timer of the spot as an item, with its value as the `title` and its time in `at`.
  `openspot timer remove <id>` removes one.
- A timer belongs to the spot that added it, and no other spot sees it. It lasts until it comes due, also across a
  restart. A spot holds at most 1000 timers, each with a value of at most 4 KB. A timer of a spot that is off or gone
  comes due into nothing.

### Let the person pick the time

Snooze, a spot of Openspot, is a grid of big tiles such as Later, Tomorrow and Pick Date. Ask it with
`openspot spot ask openspot/snooze`, and it prints the time of the tile that the person picks.

```toml
title = "Remind me"
icon = "bell"
on = ["sheet.open"]
uses = ["timer"]
```

```sh
#!/bin/sh
case "$1" in
  show) printf 'button=later\ntitle=Remind me later\nscope=spot\n' ;;
  later)
    at=$(openspot spot ask openspot/snooze) || exit 0
    [ "$at" = someday ] || openspot timer add "$at" "Look at this again"
    ;;
  due) openspot toast "$(sed -n 's/^event.value=//p')" ;;
esac
```

- It prints an ISO 8601 time with its offset, or `someday` for Someday, which has no time. A close of the sheet with
  no pick prints nothing and exits 1.
- The person sets the hours of the tiles, such as the morning and the evening, in the Settings of Snooze.

### Ask another spot

`openspot spot ask <id>` shows another spot and waits for the value it gives back, as a spot does with Snooze. Use it
to make a picker that other spots share.

- The asked spot's sheet is a step of the flow that shows, over the sheet that asked. With no sheet shown, it grows
  from the asking spot's selected row, such as a row of the main search, or opens the panel on it. A
  press that asks keeps the panel open with `close=false`, so the step takes the sheet's place in one motion.
- `--title <words>` names the asked sheet, such as the title of the tab that a snooze is for.
- The asked spot gives the value with `openspot spot reply <value>`, which hides the panel. `spot ask` prints it.
- A close of the asked spot's sheet with no reply ends the ask with exit 1, once the spot's running calls end. A newer
  ask of the same spot ends the older one the same way. A spot can't ask itself.

## The life of a call

A call starts, prints and ends. These rules say how long it can take, and what happens when it stops.

```text
start ──► frame ──► frame ──► ... ──► end    exit 0: done; another code: the last line of stderr shows
  └──► stop: a newer value, a second press or a quit; terminate signal, then kill
```

- A `show` has 10 seconds to print its first frame or end. Other calls have no limit. A frame holds at most 32 MB, and
  past it the call shows nothing more.
- A new value of a block stops the older call of that block, and a second press stops a running call: its process
  group gets the terminate signal, then the kill signal. A stopped call changes nothing.
- A spot's hotkeys run one at a time, in order, and never stop a call. At most 8 presses wait, and a later one is
  dropped. A staying spot gets each press at once, while fewer than 8 calls of its hotkeys are open.
- Exit code 0 is success. With any other code, the user sees the last line of stderr. A failure can print
  `link=<url>`, a web page that helps fix it. A failed show at `panel.open` only marks its card.
- A stop can come at any time, and two calls can run at once. Never leave a file half written.

# Reference

Here are the exact rules, tables and limits, to look up a key, a kind or an event.

## The format

The message, each frame and each report of `openspot` are lines of `key=value`.

```ini
text=title
title=Wi-Fi
detail=Home · 82 Mb/s
---
```

- A line splits at its first `=`. A blank line ends a block, and a line `---` ends a frame. In a value, `\n` is a new
  line and `\\` is a backslash. An empty value is no value, and Openspot never splits a value.
- In a frame, Openspot skips a line with an unknown key and a block of an unknown kind, and `openspot check spots`
  reports each one. In the manifest, an unknown key is a fault.

## The manifest

The manifest says what a spot is, so that Openspot can list it, find it and run it at the right time. It's the file
`spot.toml` in the spot folder.

```toml
title = "Weather"
icon = "cloud.sun"
on = ["sheet.open"]

[commands.refresh]
title = "Refresh"
```

- A spot has a sheet unless it has `[commands.<id>]` tables and no event in `on`. Such a spot runs its one command on
  Return, or opens the keys of its commands. This one lists `sheet.open` to keep its sheet beside its command.
- The keys at the top describe the script named after the folder, such as `weather.sh`. `[scripts.<name>]` describes
  each other script with the same keys, and its tables are `[scripts.<name>.commands.<id>]` and
  `[scripts.<name>.settings.<key>]`. A script holds no header.
- A value is a string in quotes, a number, `true` or `false`, or a list in brackets. `on`, `offers`, `source`, `pages`, `uses`,
  `emits` and `keywords` take a list.
- A wrong or unknown key, such as `titel`, keeps the spot from loading, and its fault names the key. The keys that only
  Openspot's own spots take are in [The app's own words](spots/AGENTS.md#the-apps-own-words).

| Key           | Value                                                                                                  |
| ------------- | ------------------------------------------------------------------------------------------------------ |
| `title`       | The name. By default, the file name.                                                                   |
| `icon`        | The icon, as in a [block](#blocks). A path that doesn't start with `/` starts at the spot folder.      |
| `detail`      | The line under the title.                                                                              |
| `keywords`    | More words that find the spot in the main search.                                                      |
| `placeholder` | The text the spot takes in a [slash command](#slash-commands), such as `"Text to translate"`.          |
| `on`          | The [events](#events) at which Openspot asks the spot what to show. A sheet needs none.                |
| `emits`       | The events the spot raises.                                                                            |
| `offers`      | `search`: its items show in the [main search](#the-main-search).                                       |
| `drop`        | The files its card takes: extensions such as `mov,mkv`, `folder`, or `*`. See [Files out](#files-out). |
| `view`        | A SwiftUI file in the spot folder, such as `"cups.swift"`. See [Views](#views).                        |
| `source`      | The Swift files, or folders of them, that a [Swift spot](#a-swift-spot) is built with.                 |
| `mode`        | `once`, the default, or `stay`. See [Modes](#modes).                                                   |
| `uses`        | What the spot uses, such as `network` or `screen`. [Uses](TRUST.md#uses) lists each one.               |
| `answers`     | `last`: the answers of `search.text` show under the other results, not first.                          |

| Table              | Meaning                                                                                                                                                                                                                                                                                                                                                                                                                                                     |
| ------------------ | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `[commands.<id>]`  | A command, with its `title` and `icon`, which the user can give a hotkey. `confirm = "<words>"` shows the words at the first press and runs it at the second, `placeholder` lists it as a slash command, and `close = false` keeps the panel open after it runs, from a slash command that shows nothing or from the ⌘K menu. It also takes the keys of a [button](#buttons-and-actions): `shortcut`, `scope` and `form`, and [`offers`](#offered-actions). |
| `[settings.<key>]` | A [setting](#settings), with its `title`, by default its key with a capital first letter, and `icon`.                                                                                                                                                                                                                                                                                                                                                       |

## The message

Each key that a call can find in its message.

| Key              | Holds                                                                                                     |
| ---------------- | --------------------------------------------------------------------------------------------------------- |
| `event=`         | On a `show`, the event that asked, such as `sheet.open`, and `event.value=` its value.                    |
| `route=`         | The [route](#pages) of the sheet that shows. The first sheet of a spot has none.                          |
| `search=`        | The search text, and `search.alt=` each text the user may have meant, such as in another keyboard layout. |
| `input.<id>=`    | Each input of the sheet or of a form. A value that isn't an input comes as `input.value=`.                |
| `setting.<key>=` | Each [setting](#settings) that has a value, a secret too.                                                 |
| `item.<key>=`    | On an action or a press of an item that holds a key of its own, each key of the item. A form gets none.   |
| `timer.late=`    | On a `due`, the seconds the timer came late. See [Act at a time](#act-at-a-time).                         |

## Blocks

Each kind of block, the keys of its own and the call it sends.

| Kind      | Shows                                                                                                            | Its own keys                                                                      | Sends                  |
| --------- | ---------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------- | ---------------------- |
| `text`    | Words.                                                                                                           | `value`                                                                           |                        |
| `number`  | One `value`, or a series of `value` lines, oldest first, with its `title` as the label. See [Numbers](#numbers). | `value`, `max`, `unit`, `display`                                                 |                        |
| `picture` | An image that fills its area.                                                                                    | `icon`                                                                            |                        |
| `view`    | The SwiftUI view the manifest names (see [Views](#views)).                                                       | any key the view reads                                                            |                        |
| `switch`  | A switch, or with `type=tick` a round tick before its words, for a thing to do.                                  | `value`: `true` or `false`, `type`                                                | `<id> true` or `false` |
| `field`   | A text field, or another input with a `type`.                                                                    | `value`, `type`, `placeholder`, `required`, `readonly`, `min`, `max`, `recording` | `<id> <value>`         |
| `choice`  | A menu of the `option` blocks after it, a list when it covers two lines or more, or swatches of `color` lines.   | `color`, `value`, `type`                                                          | `<id> <option id>`     |
| `option`  | One option of the `choice` right before it.                                                                      | `title`, `icon`                                                                   |                        |
| `button`  | A button, or an action (see [Buttons and actions](#buttons-and-actions)).                                        | `shortcut`, `confirm`, `close`, `look`, `form`, `scope`                           | `<id>`                 |
| `section` | A title over the blocks after it, or over the items after it when the layout doesn't place it.                   |                                                                                   |                        |
| `repeat`  | The place of the [items](#items).                                                                                | `grid` lines                                                                      |                        |

- Every kind also takes `title`, `detail`, `tone` and `icon`. `tone` is `good`, `warn` or `bad`, and colours the
  detail, or the title with no detail. `color=#RRGGBB` on a text or a number draws a bar of that colour at its edge.
- `icon` is an image file, such as `cups.png`; an `https://` image, downloaded once; the Finder icon of a path with a
  `/` or a leading `~`; an SF Symbol, such as `wifi`; or any other text, such as `😀`.
- `look` is the box of a text, a number or a button: `tile` or `bare`, and on a button also `chip` or `strong`.
  An item with `look=tile` in a `repeat` shows its title and detail under its icon.
  `align=left`, `right` or `center` places a block that is smaller than its area.
- A field's `type`: none for one line, `multiline`, `slider` from `min` to `max`, 0 to 100 by default, which sends a whole number, `search` for the
  search field of the [items](#items), and `hotkey`. A choice with
  `type=multiple` lets the user choose several options.
- `grow=false` keeps a block to its own lines where it would take the free height; see [Layouts](#layouts).
- A `hotkey` field shows keycaps, and records a key at Return or a click on it, or when a new frame gives it
  `recording=true`. Every key goes to it, Esc brings back its key, and a shortcut sends `<id> <key>`. While a sheet
  with one shows, Openspot's own keys are off.

## Events

Each event that Openspot raises, when it raises it, and the value that the show gets as `event.value=`.

| Event              | When Openspot raises it                                                              | Value                            |
| ------------------ | ------------------------------------------------------------------------------------ | -------------------------------- |
| `sheet.open`       | When the spot's sheet opens. List it to ask again within 5 seconds, or to give a spot with commands a sheet. |                                  |
| `panel.open`       | Each time the panel opens, and once when Openspot starts.                            |                                  |
| `clock.<seconds>`  | Every that many seconds while a place of the spot shows, and when the Mac wakes.     |                                  |
| `search.text`      | At each change of the main search text.                                              | the text                         |
| `sheet.text`       | At each change of the sheet's search text, and when the sheet opens.                 | the text                         |
| `clipboard.change` | When the clipboard changes.                                                          |                                  |
| `app.front`        | When another app comes to the front.                                                 | its bundle ID                    |
| `app.update`       | When Openspot has downloaded an update.                                              | its version                      |
| `app.launch`       | Once when Openspot starts.                                                           |                                  |
| `screen.wake`      | When the screen wakes.                                                               |                                  |
| `system.load`      | Every 5 seconds while a place of the spot shows.                                     | `cpu=<percent> memory=<percent>` |
| `power.change`     | When the Mac moves to another power source, or its battery gains or loses a percent. | `ac`, `battery` or `ups`         |
| `disk.mount`       | When a disk or a volume mounts.                                                      | its path                         |
| `device.connect`   | When a USB device connects. A Bluetooth device raises no event.                      | its name                         |

## Versions

The version at the top is the version of this protocol. A new word raises the minor number, such as `2.1`. A draft
becomes `final` when real use proves it, and a final version never changes the meaning of a word. A change that breaks
an old spot raises the major number.

## How to extend

An old spot never sees a word it didn't ask for. An older Openspot skips a word of a frame that it doesn't know, and
doesn't load a spot whose manifest has a key that it doesn't know.

| To add               | Add                                                              |
| -------------------- | ---------------------------------------------------------------- |
| A thing that happens | an event `<noun>.<verb>`                                         |
| A place to show      | a size of a layout, `grid.<size>=`                               |
| A thing to draw      | a kind `<kind>=`, which an older Openspot skips and reports      |
| A detail of a kind   | a key, or a `type` value                                         |
| A power of the Mac   | a noun: `openspot <noun> <verb>`, its events and its `uses` word |
| A complex look       | nothing: a `view` of the spot                                    |
