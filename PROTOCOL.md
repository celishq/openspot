# Openspot protocol

`3.0` `draft`

This is the contract between a spot and Openspot. The overview teaches its words. Then
[Print blocks](#print-blocks) is enough for most spots, [Lay out and react](#lay-out-and-react) makes a spot answer the
person, and [Advanced](#advanced) covers the rest, so you can stop as soon as your spot does what you need.
[Reference](#reference) holds the exact tables. To learn by example, start with the [guide](GUIDE.md). What
the person chooses, such as the keys and places of a spot, is in [What the user chooses](GUIDE.md#what-the-user-chooses),
and what Openspot shows the person about a spot is in [Trust](TRUST.md).

## Overview

A spot declares what it has in `spot.toml`, and its code decides what to do. Each trigger, such as a press, an event or
a timer, calls a handler named for it. The handler answers with a frame or with values, and makes each change through
`openspot` commands. What it prints flows one way, into what the person sees, and only a press on it starts the loop
again.

```text
  ┌──────────── the person presses, a timer comes due, or the Mac changes ◄────────────┐
  ▼                                                                                     │
trigger ──► handler ──► frame or values ──► Openspot draws it in each place ──► the person sees it
               │
               └──► openspot <noun> <verb>      each change, such as a toast, a timer or a run of another spot
```

- **Spot:** a folder that Openspot runs, a script and its manifest, `spot.toml`. See [A spot](#a-spot).
- **Manifest:** what the spot keeps, does, tells, uses, binds and listens to, as formats with no logic. See
  [The manifest](#the-manifest).
- **Handler:** one call of the spot, named for what triggered it, with typed values on stdin. See [The calls](#the-calls).
- **Action:** a thing the spot can do, with typed inputs and outputs. See [Actions](#actions).
- **Frame:** everything a handler shows at one time, a tree of blocks, or the values it gives. See [Frames](#frames).
- **Block:** one thing in a frame, such as a text, a number or a switch. See [Show things with blocks](#show-things-with-blocks).
- **Command:** `openspot <noun> <verb>`, the one way a spot changes anything. See [The openspot command](#the-openspot-command).

## Principles

These rules hold everywhere, and the details follow from them.

- **The manifest declares, and the code decides.** `spot.toml` holds types and names, never a mapping or a rule. Each
  trigger calls a handler, and the handler chooses what to do.
- **A spot gives data, and Openspot draws it.** A block says what a thing is, such as a [number](#show-a-number) or a
  [series](#show-a-series), and its keys say what it holds. [Classes](#classes) say where a block sits and how it looks,
  and every size and colour they name comes from the theme.
- **A frame describes, and a command changes.** Printing a frame never changes the Mac, and a read, such as `show`,
  runs no command that changes anything.
- **The person chooses the places and the keys.** The spot lays out each place it cares about.
- **A spot keeps no state between calls.** Openspot asks it again at each event it listens to, and each show replaces
  the last, so a call can end at any time.
- **Each meaning has one form.** Every value reaches a handler as `input.<name>=`, every value it gives back is
  `out.<name>=`, and a key such as `title` means the same on every block.
- **Text first.** A spot is any program that prints lines of `key=value`. A [view](#views) is only for a look that
  blocks and classes can't give.

# Print blocks

At its simplest, a spot is a manifest with a title and a script that prints blocks, and Openspot lays them out. This is
the minimum a spot needs.

## A spot

A spot is a folder that Openspot runs: a manifest that names it, and a script that prints what to show. See
[Your first spot](GUIDE.md#your-first-spot).

- A **spot folder** is a folder `<name>.spot` in the spots folder, such as `coffee.spot`. It holds `spot.toml`, the
  [manifest](#the-manifest), its script, a `readme.md`, a `sample.sh` and any file they need. Its id is the name of
  the folder, such as `coffee`, and its script has that name too, such as `coffee.sh`. Another script in the folder can
  hold shared code. The folder is shared as one unit of at most 25 MB.
- `sample.sh` prints what the spot would show, with made-up data. Publish ships its output as `sample.frame`, which the
  store of spots shows, and where a click runs nothing.
- A line of `readme.md` that holds only a Markdown image of a file in the folder shows that PNG, JPEG, GIF, MOV or MP4.
  An `https` picture is fetched once, with no cookies, and an `https` video shows as a link.
- Openspot moves a loose script into a spot folder of its name, and writes a `spot.toml` with the script's title.
- An agent can do anything the person does. `openspot spot actions [id]` lists each action of a spot, and each
  command of its uses, with their inputs and outputs as JSON Schema, and
  `openspot spot run <spot> <handler> [<name>=<value>...]` calls one handler as Openspot would, with its bindings live.
  A spot can't tell who called it.

## The calls

A call works like a CGI call: the handler's name as an argument and its values on stdin go in, and frames come out.
Openspot makes a call at each of these triggers. See [Show a list](GUIDE.md#show-a-list) and
[Add actions](GUIDE.md#add-actions).

| Call                       | When                                                                                       | Inputs                         |
| -------------------------- | ------------------------------------------------------------------------------------------ | ------------------------------ |
| `<spot> show`              | An open of its sheet, a place that needs its view, and `panel.open`, `sheet.open` or `spot.want` in its `[on]`. | `event`, `route` |
| `<spot> <action>`          | The person runs an [action](#actions), a block with the action's id is pressed or changed, a timer comes due, a view sends, or a spot that binds it runs it. | the action's `inputs`, and `item` or `value` |
| `<spot> press`             | Return or a click on an item, or a press of the card of a spot with no sheet.              | `item`, and `item.<key>`       |
| `<spot> command`           | The person types `/<word>` of a word in `command` of its `[on]`. See [Slash commands](#slash-commands). | `name`, `text`  |
| `<spot> search`            | A text of the main search that matches `search` of its `[on]`. See [The main search](#the-main-search). | `text`, `alt`   |
| `<spot> every`             | Every `every` seconds of its `[on]` while one of its places shows, and when the Mac wakes. |                                |
| `<spot> schedule`          | A cron line of `schedule` in its `[on]`, shown or not. See [Act at a time](#act-at-a-time). | `cron`, `late`                |
| `<spot> drop`              | A drop of files on its card. See [Files in and out](#files-in-and-out).                    | `file`, once for each path     |
| `<spot> drag`              | A drag of items that stand for files out of its sheet.                                     | `item`, once for each item     |
| `<spot> <event>`           | Any other [event](#events) in its `[on]`, such as `system.load`.                           | `value`                        |
| `<spot> <binding>.<event>` | An event of a spot that it binds. See [Tell other spots](#tell-other-spots).               | the values of that event       |

- **Arguments:** the handler's name, so that `case "$1"` handles each call. An action takes no name of a handler that
  its `[on]` calls, nor `show`, `press` or `drag`, and a spot that breaks this doesn't load.
- **Stdin:** the message, whose keys are in [The message](#the-message): each input as `input.<name>=`, and each setting
  as `setting.<name>=`. Each process that the spot starts inherits it, unless the spot reads it first or closes it for
  that process, such as `curl "$url" </dev/null`.
- **Variables:** `OPENSPOT_ID`, the spot's id; `OPENSPOT_DATA`, the data folder of its spot folder; `OPENSPOT_SH`, the
  shell helper; `PATH`, with the `openspot` command first, then the person's paths, `/opt/homebrew/bin`,
  `/usr/local/bin`, `/usr/bin`, `/bin`, `/usr/sbin` and `/sbin`; and `LC_ALL=en_US.UTF-8`, so each tool reads text as
  UTF-8 on every Mac. A command that handles raw bytes sets `LC_ALL=C` for itself.
- **The moment:** `show` gets the event that asked for it as the input `event`, such as `panel.open` or `sheet.open`,
  so a show can do less when the panel opens.
- **Reads:** `show`, `search`, `every` and an event's handler are reads. A read changes nothing and opens nothing; see
  [The openspot command](#the-openspot-command).
- **The end:** a handler that answers with a view shows it, and one that answers with no view closes the panel, unless
  the block or item that was pressed has `close=false`.

The shell helper, `. "$OPENSPOT_SH"`, reads stdin once and keeps it, and writes values for you. After it loads, read
stdin with `value` or `openspot_input`, not `cat`: the function of `openspot_serve` gets an empty stdin.

| Function                                     | Does                                                                                            |
| -------------------------------------------- | ----------------------------------------------------------------------------------------------- |
| `esc <text>`                                 | Prints text as a value.                                                                         |
| `value <name>`                               | Prints each value of the input `<name>`, or of the key `<name>`, such as `setting.city`, one per line, in order. |
| `openspot_value <key> <text>`                | Prints each value of the key from a text, such as what an `openspot` command printed.           |
| `openspot_input`                             | Prints the stdin of the call as it came.                                                        |
| `openspot_kv <key> <value>`                  | Prints one line, with its value escaped.                                                        |
| `openspot_item <id> <title> [detail] [icon]` | Prints one item, an `item` block.                                                               |
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
  `frame=` line changes only the blocks it prints, as [Change a block](#change-a-block) says.
- If a show prints nothing, the spot shows nothing. If another call prints nothing, Openspot calls `show` again.
  Openspot ignores what an out-of-date call prints.
- Print a value that comes from data with `openspot_kv`, `openspot_item`, `esc` or `openspot.frame`, so that it can't
  add a line or a block.
- Openspot removes escape codes, such as colours and terminal progress, from the output. Show progress with
  `progress=` and a toast with `openspot toast`.

### The root

The root is the block that starts with `frame=`, with `error=`, or with a value of the call, as the last rule says. It
holds the blocks that name no parent and the words of the card, and isn't drawn.

- `frame=<route>` starts it. The route is the name of the sheet the frame is for, and can be empty; see
  [Pages](#pages).
- `class` gives the frame a layout and lays out the blocks of the root, as on a box; see [Layouts](#layouts).
- It takes `title`, `detail` and `active` for the card, and `recents`.
- `value=<id>` names the block that is the spot's value on [the card](#the-card), in [the menu bar](#the-menu-bar)
  and in [the main search](#the-main-search).
- `type=form` makes the frame a form, when it answers a press; see [Ask for values](#ask-for-values).
- `progress=<0 to 1>` shows progress, and then `title` and `detail` show only on the running call.
- `error=<message>` fails the call with the message; see [The life of a call](#the-life-of-a-call).
- `call=<n>` and `end=<n>`, here or in a block of their own, mark each call of a [staying spot](#a-staying-spot), one
  process that answers many calls.
- The root can come anywhere in the frame. Openspot skips and reports a second root. A frame with only a root changes
  no block.
- `out.<name>=<value>` gives a value of an action's `outputs`, once for each value. See [Actions](#actions).

## Show things with blocks

Print one block for each thing the spot shows: words, a number, a switch, an item of a list. See
[Your first spot](GUIDE.md#your-first-spot).

```ini
item=home
title=Home
detail=82 Mb/s

switch=vpn
title=VPN
value=true

button=forget
title=Forget
```

The sheet lists two rows: Home with 82 Mb/s under it, and VPN with its switch on. Forget is a row of the ⌘K menu, not
of the list.

- The first key of a block is its kind, and its value is the block's id. Anything with its own title or icon is a block.
- The id names the block in the layout, the action it runs and what moves when it changes. A second block with the same
  id changes the first, as [Change a block](#change-a-block) says. Each kind keeps its data in `value`, and a kind that
  shows several values repeats it.
- A frame with no [layout](#layouts) gets the one Openspot makes: a list of the blocks, which the person searches. Each
  block is an [item](#items), except a `button`, which is a row of the ⌘K menu, and a `choice`, which shows over the
  list. A row of words there is an `item` block, as in [Items](#items).
- [Blocks](#blocks) lists each kind, its own keys and the keys that every kind takes.

# Lay out and react

Here you place blocks where you want them, show a spot outside its sheet, and answer the person and the Mac.

## Layouts

A layout places the blocks of a frame. Put a block inside another with `parent`, and say how each box lays out what it
holds with `class`, in the words of Tailwind CSS. See [Lay out a sheet](GUIDE.md#lay-out-a-sheet).

```ini
frame=
class=gap-3 p-3

box=head
class=flex-row items-center gap-2

icon=wifi
parent=head
value=wifi
class=text-accent

text=name
parent=head
title=Home
detail=82 Mb/s
class=grow

button=forget
parent=head
title=Forget
class=rounded-full

items=networks

item=office
parent=networks
title=Office
detail=54 Mb/s

item=cafe
parent=networks
title=Café
detail=12 Mb/s
```

The sheet shows one row: the Wi-Fi icon in the accent colour, Home with 82 Mb/s under it, and a Forget chip at its
end. Under it, Office and Café are the items of the list.

- `parent=<id>` puts a block inside the block with that id. A block with no `parent` sits in the root. Blocks that
  share a parent keep the order of their lines.
- A frame has a layout when its root has a `class`, such as `class=gap-part`, or when it holds an `items` block. Each
  block then draws where the layout puts it, and only the blocks inside the `items` block are [items](#items). A frame
  with no layout gets the one that [Show things with blocks](#show-things-with-blocks) says.
- A `box`, a `parent` or a class on another block doesn't make a layout. In a frame with no layout,
  `openspot check spots` reports each `box` and `parent`, and a class there styles its block only where the frame
  draws a tree, such as on a card.
- A `box` holds blocks. It lays them out in a column, or in a row with `flex-row`, a grid with `grid grid-cols-<n>`, or
  layers with `relative`. It draws nothing of its own but what its classes give, such as a fill. The root is a box too.
- In a grid, `col-span-<n>` and `row-span-<n>` make a block cover more cells. In layers, `absolute` with `inset-0`, or
  with an edge such as `top-0`, pins a block to its box.
- A divider is a box with `class=h-px bg-tile`, a line as thin as Openspot's own dividers.
- The arrows move the keys through each switch, field, choice and button in the order of the tree, above the items
  and under them.
- `grow` takes the free space of a row or a column. Blocks that grow in one row get equal widths, as `flex-1` gives in
  CSS. An `items` block, a `multiline` field and a [view](#views) with no height take the free height of their box by
  themselves, and `grow=false` keeps one to its own height.
- `gap-part` and `gap-group` are the gaps that Openspot's own sheets use. [Classes](#classes) lists every class.
- A `parent` that names no block, and an unknown class, are faults that `openspot check spots` reports. The block then
  sits in the root, and the class is skipped, so a frame still draws.
- The check also reports more than one button with `bg-accent`, a title that may not fit its place, and a `text` that
  its classes make shorter than its words. It guesses the width of the words, so a text of wide letters may still be
  cut.

### Change a block

A block with the id of a block that shows changes that block, so a spot can change one thing while the rest stays.
After the frame above, the same call can print this frame, with no `frame=` line:

```ini
text=name
title=Office
```

The row now shows Office with 82 Mb/s under it, in the same place.

- A block of the same kind changes only the keys it prints. The other keys stay, and so does its place.
- A block of another kind replaces the block, with only the keys it prints. It keeps the place and the blocks inside it.
- A new `parent=<id>` moves the block into that block, and `parent=` with no value moves it to the root.
- A `button` with a `scope` changes by its id too, like any other block.
- An `option` belongs to the `choice` that it follows. A `choice` printed again with its options takes the new
  options, and one printed with none keeps its options.
- A block with a new id joins the end of its parent.
- A later block in the same frame changes an earlier one by the same rules. A frame with a `frame=` line replaces all.

## Places

A place is where a frame shows. One tree draws in each place, and a class with a place before it, a **variant** such as
`card:hidden`, applies only there. See [Show a value on a card](GUIDE.md#show-a-value-on-a-card).

```ini
frame=
class=p-3 card:p-0

number=battery
title=Battery
value=84
max=100
unit=%
type=ring
class=hidden card:flex card:h-full

items=list
class=card:hidden
```

The sheet shows the list. A card shows only the battery, a ring around 84%, with Battery above it on a square card.

| Place                                       | Where                                                              |
| ------------------------------------------- | ------------------------------------------------------------------ |
| `small`, `wide`, `square`, `strip`, `large` | A card in the panel. The person chooses its size.                  |
| `bar`                                       | The menu bar, next to the clock. A click opens the sheet under it. |

- A card shows the spot in the panel, which Openspot's hotkey opens, and the spot's sheet fills the panel when the
  person opens the spot. A spot can also show in a float, a small window at the pointer, and in a window, a normal
  window that holds its sheet.
- Each place has a variant of its name, such as `card:` on a card of any size and `wide:` on a wide card.
  [Variants](#variants) lists them.
- The person chooses the places, and the spot only lays out the ones it cares about. A card draws the tree once a class
  names `card:` or the card's size. A card with no such class shows the spot's icon, title and detail, and
  [the menu bar](#the-menu-bar) has its own rule.

### The card

The card stands for the spot in the panel.

- Its **value** is the one `text`, `number`, `series`, `switch` or slider that shows on the card, or else the one among the
  items. When the card shows more than one, `value=<id>` in the root names it, and `openspot check spots` reports a
  card that shows more than one with no `value`.
- `active=true` in the root shows that the spot's thing is on. A switch that the card places shows its own value, and
  doesn't fill the card.
- The card draws what a `card:` class places, such as `class=card:flex` on a `switch`, and a press on a switch it
  places flips it. When a switch or a slider is all that the card places, a press anywhere on the card changes it.
  Any other press does what Return does; see [The keys of a spot](GUIDE.md#the-keys-of-a-spot).
- The card's title and detail come from the root, or else from the manifest, never from a block that it places.

### The menu bar

The menu bar shows the first value that shows on `bar:`, or the one that `value` in the root names, small, beside the
clock, once a class names `bar:`, such as `class=bar:flex` on a `number`.

- A `number` with `type=ring` or `type=bar` is a small ring with its value, and any other `number` is its value. A
  `series` is its last 8 bars with its value.
- A `text` or an `item` with a `tone` and no `icon` is a dot of its tone and its title. Any other `text` or `item` is
  its title.
- With no class that names `bar:`, the menu bar shows the spot's icon. A `switch` or slider that shows on `bar:` hides
  the spot there.
- A show that prints nothing hides the spot in the menu bar until the next show.

## Show a number

A number shows one value, such as the battery, as text, a ring or a bar.

```ini
frame=
class=grid grid-cols-2 gap-part

number=battery
title=Battery
value=84
max=100
unit=%
type=ring
class=h-32

number=disk
title=Disk
value=62
max=100
unit=%
type=bar
class=h-32

number=cups
title=Cups today
value=3
class=col-span-2 h-20
```

Battery is a ring around 84%, and Disk a bar filled to 62% under Disk and 62%. Below them, a 3 in big type sits over
Cups today.

- `value` is the number. `unit` follows it, as in `84%` or `12 kg`, and `display` shows instead of it, as in
  `display=–`.
- With no `type`, a number is its value as text. `type=ring` draws a ring and `type=bar` a bar, filled to `value` out
  of `max`. A ring or a bar with no `max` is a fault that `openspot check spots` reports.
- A number holds one `value`. Points over time are a [series](#show-a-series).

## Show a series

A series shows points over time, such as the use of the CPU over the last minutes, as its last value over a bar for
each point.

```ini
frame=
class=gap-part

series=cpu
title=CPU
value=12,30,18,-,25,40,22
max=100
unit=%
class=h-32
```

A tile shows CPU and 22% in big type, with a small bar for each point at its lower right and a gap for the `-`.

- `value` holds the points, oldest first, split by commas. `-` is a point with no value, drawn as a gap. A later
  `value` replaces all the points.
- `max` is the value of a full bar, and by default the largest point. `unit`, `display` and `title` work as on a
  number.

### Add points to a series

A [staying spot](#a-staying-spot) adds points to a series without printing them all again: a later block with the
series' id names them in `add`.

```ini
series=cpu
add=31
```

After the block of the example above, the tile shows 31%, and a bar for 31 joins the others at the right.

- `add` takes one point or more, split by commas, and puts them after the last. A block with both `value` and `add`
  replaces the points, then adds.
- `keep` is the most points that a series holds, 60 by default and 600 at most. When an add passes it, the oldest
  points drop.

## Listen for events

An event, such as the panel opening or the power source changing, calls the spot when its `[on]` names it. See
[Respond to the Mac](GUIDE.md#respond-to-the-mac).

```toml
title = "Power"
icon = "powerplug"

[on]
"panel.open" = true
"power.change" = "^(ac|battery)$"
```

At each open of the panel, Openspot calls `power show`. When the Mac moves to its charger or its battery, it calls
`power power.change` with `input.value=ac` or `input.value=battery`.

- Each key of `[on]` that names an [event](#events) is one the spot listens to. `panel.open`, `sheet.open` and
  `spot.want` call `show`. Each other event calls the handler of its own name, with its value as the input `value`,
  such as `system.load` with `value=cpu=12 memory=40`.
- `true` takes the event each time. A string is a regular expression that the value must match. An event with no
  value, such as `clipboard.change`, takes only `true`.
- An event's handler is a read, as `show` is, and its frame draws as a show's does.
- The sheet calls `show` at each open, unless it called it less than 5 seconds ago. With `"sheet.open" = true`, it calls
  it again even then. Openspot calls a spot only while one of its places shows, except at `app.launch` and
  `app.update`. A spot has one read at a time.
- Openspot also calls `show` after a call that printed nothing, and with `spot.want` when a place starts to show a spot
  whose events haven't come yet.
- `every = <seconds>` in `[on]` calls `every` at that pace while one of the spot's places shows, and when the Mac wakes.
  Its frame draws as a show's does.
- At load, Openspot checks each key of `[on]`. An unknown event, a filter on an event with no value, or a
  `<binding>.<event>` whose binding isn't in `[bindings]` keeps the spot from loading, and its fault names the key.

## Actions

An action is a thing the spot can do, with typed inputs and outputs. The person runs one with a title, a block runs the
one its id names, and a timer, a view or another spot runs any of them. See [Add actions](GUIDE.md#add-actions).

```toml
title = "Tea"
icon = "cup.and.saucer"

[actions.brew]
title = "Brew Tea"
inputs.minutes = { type = "number", default = 4, description = "How long the tea steeps" }
outputs.ready = "date"
```

```sh
#!/bin/sh
. "$OPENSPOT_SH"
case "$1" in
  brew)
    ready=$(date -u -v+"$(value minutes)"M +%Y-%m-%dT%H:%M:%SZ)
    echo "out.ready=$ready"
    ;;
esac
```

Brew Tea shows in the main search and the ⌘K menu, and the person can give it a key. A run calls `tea brew` with
`input.minutes=4`, and the spot gives the time the tea is ready.

- `[actions.<id>]` holds one action. `inputs.<name>` and `outputs.<name>` take a [type](#types), such as `"date"`, or a
  table of `type`, `required`, `default`, `description` and `options`.
- An action with a `title` is one the person runs: it shows in the main search, the ⌘K menu and the spot's Settings,
  where the person gives it a key. `icon` gives it an icon, and `confirm = "<words>"` shows the words at the first press and runs
  it at the second. An action with no title runs only from a block, a view, a timer or a run.
- Before a call, Openspot checks each declared input and fills its default. A wrong type, or a required input that is
  empty, keeps the call from running, and an input it doesn't declare, such as another field of the sheet, passes
  unchecked.
- An action gives its values as `out.<name>=` lines in its frame's root, or answers with a view instead. Openspot
  checks the values against `outputs` only on a frame that holds an `out.` line.
- `openspot spot actions` lists each action and each command of the spot's uses, typed as JSON Schema, so an agent can
  call it.

### Ask for values

When the person runs an action whose required input is empty and has no default, Openspot asks for it with a form drawn
from the types. See [Ask for values](GUIDE.md#ask-for-values).

- A `bool` is a switch, a `choice` a menu of its `options`, and every other type a field, with its default as its
  value and its `description` as its placeholder. An empty field counts as no value, so its default applies.
- A global key shows no panel, so the call it makes fails with a line that names the input.
- A handler can also print its own form, a frame whose root has `type=form` and a `title`, with a `field`, `choice` or
  `switch` for each value. Its values go to the same action, or to `press` again for a form that answered a press of an
  item. A form whose handler answers with `error=<message>` stays
  open and shows the message. In a choice with `type=multiple`, a `value` line marks each chosen option.
- A form whose only field is a `choice` lists its options, which the person searches, and Return sends the selected one.
- The words typed after a button in the main field fill the first required `text` input of its action. When another
  required input is still empty, Openspot asks with the drawn form, that input filled.
- When a search of the sheet finds no item, Return offers the first `scope=spot` button whose action has a required
  input of type `text`, or else the first action with a `title` and such an input. Return opens its drawn form with the
  searched words in that input, and a second Return runs it.

## Buttons and actions

A button is a verb, such as Forget, that the person presses in the sheet or in its ⌘K menu. A press runs the action
that its id names. See [Add actions](GUIDE.md#add-actions).

```ini
button=save
title=Save
class=bg-accent

button=rename
title=Rename
scope=spot
shortcut=cmd+r
```

The sheet shows Save as its main button, across its width. Rename is a row of the ⌘K menu, and ⌘R presses it.

- A button is a row of the ⌘K menu when it has a `scope`, sits inside the `items` block, or is in a frame with no
  layout. Any other button draws where the layout places it. A press calls `<spot> <id>`.
- A button of the ⌘K menu passes the selected item as the input `item`, with its own keys as `item.<key>`.
  `scope=item`, the default, shows it only while an item is selected, and `scope=spot` always. Such a button needs a
  `title`.
- A press of a `field`, `switch` or `choice` passes its value as the input `value`, as a view's `spot.send` does.
- The id needs no `[actions.<id>]`. Declare one to type its inputs.
- `close=false` keeps the panel open after a press that answers with no view. A `switch`, a `choice` or a hotkey
  `field` closes the panel after it sends its value only with `close=true`, and a text field or a slider doesn't close
  it, since it sends as you type or drag. `confirm` asks for a second press.
- Return on an item calls `press`, and `button=press` gives Return a `title` in the ⌘K menu and the footer.
- `shortcut` is a letter, a digit, `return`, `backspace` or `,`, after `cmd+`, `shift+`, both or neither, or `escape`
  alone, which presses the button instead of closing the sheet. In a ⌘K menu of 3 rows or more, only a `shortcut`
  with `cmd` works, since a field searches the rows.

## The openspot command

A spot asks the Mac and Openspot for everything it does through `openspot <noun> <verb>`, which works the same in a
terminal. [The openspot commands](app/Help/commands.md), which `openspot guide commands` prints, lists each one.

- A noun names its commands, its events and its use, such as `openspot clipboard copy`, `clipboard.change` and
  `clipboard` in `uses`. When macOS already has a command, such as `open <url>`, use it.
- `openspot toast <words>` shows the words for a moment, `openspot select <item>` selects an item once the next frame
  shows, and `openspot route` moves between [sheets](#pages). They work for the call that ran them, and do nothing when
  it's out of date. From a terminal, they work on the sheet that shows.
- A read changes nothing and opens nothing, so a command that waits for the person, captures the screen, changes the
  Mac, Openspot or the sheets that show, or opens a window fails in it; see
  [the commands that fail in a read](app/Help/commands.md#the-commands-that-fail-in-a-read).
- A command exits 0 when it's done, 1 when it failed, 2 when `openspot` doesn't take its words, 3 when Openspot didn't
  answer, and 4 when the person closed what it showed. A wrong type, an undeclared binding and an undeclared event are
  words it doesn't take. A command that has no answer prints `status=<word>`. A list or a report prints blocks, or
  JSON with `--json`.
- Each command declares its inputs and outputs, so `openspot spot actions` lists the commands of a spot's uses, and
  `openspot types` types them for its code.

## Items

Items are the list that the person searches and presses. See [Show a list](GUIDE.md#show-a-list).

```ini
items=devices

box=nearby
parent=devices
title=Nearby

item=mouse
parent=nearby
title=Mouse
icon=computermouse
keywords=pointer

number=keyboard
parent=nearby
title=Keyboard
icon=keyboard
value=62
max=100
type=ring

button=forget
parent=devices
title=Forget
```

The sheet lists Mouse and Keyboard under the title Nearby, each with its icon, and Keyboard ends in a ring around 62.
Forget is a row of the ⌘K menu of the selected item, and a search for pointer finds Mouse.

| Key          | Meaning                                                                                         |
| ------------ | ----------------------------------------------------------------------------------------------- |
| `title`      | The first line. By default, the id.                                                             |
| `detail`     | The line under the title.                                                                       |
| `icon`       | The icon.                                                                                       |
| `tone`       | A dot of its colour on the icon.                                                                |
| `value`      | `true` draws a checkmark.                                                                       |
| `place`      | Where the item sits in its spot. The [main search](#the-main-search) shows `<spot> › <place>`.  |
| `keywords`   | Words that find the item but don't show, split by commas.                                       |
| `pin`        | `top` or `bottom`: the item stays above or under the items that scroll, even in a search.       |
| `hides`      | The id of a button of the ⌘K menu that this item doesn't offer. One line for each button.       |
| `file`       | The file the item stands for. See [Files in and out](#files-in-and-out).                        |
| `open.title` | What Return does on this item, in place of the `title` of `button=press`.                       |
| `route`      | A [route](#pages) that a press opens at once, in place of a call of `press`.                    |
| `close`      | `false` keeps the panel open after a press of this item, or a key it records.                   |
| `shake`      | `true` on a `hotkey` field: a shake or a tap of one modifier can be its key.                    |

- The blocks inside the `items` block are the items, and a `button` there is a row of the
  [⌘K menu](#buttons-and-actions). A `box` inside the `items` block is a group: its `title` heads the items inside it.
  A frame with no layout makes its items as [Show things with blocks](#show-things-with-blocks) says.
- An `item` block is a row of words: its `title` and `detail`, its icon, and the keys above. It belongs in a list. A
  `text` in a list, and an `item` outside one, are faults that `openspot check spots` reports. The block still shows.
- A `number` item shows its value on the right of its title, or a ring of it with `type=ring`, as in
  [Show a number](#show-a-number). A `series` item shows the bars of its points.
- A press of an `item` calls `press` with its id as the input `item`, a press of a switch runs its action with
  `value=true` or `false`, and a press of a `hotkey` field records a key. An item can hold keys of its own, such as
  `meeting=42`, which come back as the input `item.meeting`.
- A frame has one `items` block. Its classes lay out each item, such as `grid grid-cols-4` for a grid of tiles. In a
  grid, each item shows its icon with its title and detail under it, and `class=sr-only` on an item shows only its
  icon.
- An item is one block. A block inside an item, such as a `box` in the `items` block, doesn't show, and
  `openspot check spots` reports it.
- In a frame with a layout, only a `field` with `type=search` adds a search field, and it draws where the layout puts
  it. Openspot searches the items and puts the items pressed most recently first, unless the root has `recents=false`.
- With `"sheet.text" = true` in `[on]`, each change of the text calls `sheet.text` with the text as `value`, and each
  text the person may have meant, such as in another keyboard layout, as `alt`. The spot prints the items that match.

### The main search

The main search, the panel's own search field, lists items from every spot. See
[Answer the main search](GUIDE.md#answer-the-main-search).

- `search = true` in `[on]` adds the items of the spot's `show` to it. With no `panel.open` or `every` in `[on]`,
  Openspot asks for the items when it loads the spots and at each open of the sheet.
- `search = "<pattern>"` in `[on]` calls `search` at each change of a text that matches, with the text as `text` and
  each text the person may have meant, such as in another keyboard layout, as `alt`. A newer text stops the older call.
  Its items show first, or under the others with `answers = "last"` in the manifest. A spot whose only trigger is
  `search` has no card.
- `answers = "card"` in the manifest shows one card instead of the items: the card of the frame's
  [value](#the-card), and a press calls `press` with that value as `item`. The card is large when a class names
  `large:`, and a strip otherwise. A frame with no value still shows its items.

## Settings

A setting keeps a choice of the person, such as a city or a token. See
[Let the user choose a setting](GUIDE.md#let-the-user-choose-a-setting).

```toml
title = "Weather"

[settings]
city = { type = "text", title = "City", default = "Paris" }
units = { type = "choice", options = ["Celsius", "Fahrenheit"], default = "Celsius" }
token = { type = "secret", title = "Token" }
```

The spot's Settings list City, Units and Token, each set or Not set. Each call gets `setting.city=Paris` and
`setting.units=Celsius` on stdin until the person changes them.

- `[settings]` holds one key for each setting, with a [type](#types), and `title`, `icon`, `default`, `description` and
  `options`. The title is by default the key with a capital first letter.
- Each call gets each setting on stdin, such as `setting.city=Paris`, or its default when it has no value, so the spot
  reads it with no `openspot` call. A JavaScript spot reads them in `env.settings`.
- A `choice` or a `bool` is one that Openspot shows and keeps, with no call. Return on any other setting in the spot's
  Settings calls the handler of the same name, which can answer with a form.
- A `secret` keeps a value of 8 characters or more, such as a token, in the Keychain. Openspot asks for it in its own
  form, never puts it on stdin, and hides the exact value in the call log, the stats, a toast and a failure line. The
  spot reads it with `openspot setting get <name>`.
- `openspot setting set <key> [value]` keeps a value, or removes it. A setting can't use a key that Openspot keeps for
  the person; see [The Settings of a spot](GUIDE.md#the-settings-of-a-spot). Keep what the spot makes, such as a cache,
  in `OPENSPOT_DATA`.

# Advanced

These rules are for a spot that needs more than one sheet, a process that stays, an answer in the same keystroke, a look
of its own, a time to act, or another spot.

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
- Each call of a sheet with a route gets it as the input `route`. A route matches a `pages=` line, where `*` stands for
  any text. A spot with no sheet gets `press` with the route as `item` instead.
- A spot moves only its own routes, while its sheet shows. It never takes off another spot's sheet and never closes the
  panel, and a read never moves between sheets.

## Modes

A mode says how Openspot runs the program of a spot.

- Openspot starts a process for each call, unless the manifest has `stay = true`.
- `stay = true` keeps one process, which gets each call on stdin while one of its places shows, or from launch to quit
  with `"app.launch" = true` in `[on]`.
- A `.js` file with no execute permission runs inside Openspot.

### A staying spot

Use a staying spot to keep a window, a device or a stream open across calls. It gets each call on its stdin and answers
on its stdout.

```toml
title = "Relay"
stay = true

[actions.send]
title = "Send"
```

```sh
#!/bin/sh
. "$OPENSPOT_SH"
main() {
  case "$1" in
    show) printf 'frame=\nclass=gap-part\n\nbutton=send\ntitle=Send\n' ;;
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
- A shell spot that waits in `openspot run` takes no other call until the run ends. Openspot sends it no read meanwhile,
  and the main search keeps its last answer.
- When no place shows the spot and no call waits, Openspot closes its stdin. The spot ends with each process it
  started, or its group gets the terminate signal 2 seconds later, and the kill signal 2 seconds after that.
- After 3 failures in one minute, Openspot starts the spot again only when its file changes. Keep what must survive in
  `OPENSPOT_DATA`.

> **Note:** A program that doesn't use `openspot_serve` reads and writes the calls itself. Openspot writes each call to
> stdin as one block: `call=<n>`, an `arg` line with the handler's name, then the message. The program prints
> `call=<n>` before the output of each call and `end=<n>` after it, and a frame of only `call=<n>` starts the output of
> that call. A stop of a call comes as `stop=<n>`.

### A JavaScript spot

A JavaScript spot runs inside Openspot, so it answers in the same keystroke, and its handlers can wait for the person
or another spot. Use it for a spot that answers as the person types; [Answer the main search](GUIDE.md#answer-the-main-search)
shows one.

```toml
title = "Greeting"

[actions.greet]
title = "Greet"
inputs.name = { type = "text", default = "you" }
outputs.words = "text"
```

```js
export default {
  async show(input, env) {
    return [{ item: "hello", title: "Hello" }]
  },
  async greet({ name }, env) {
    return { words: `Hello, ${name}.` }
  },
}
```

The sheet lists Hello. Greet gives `out.words=Hello, you.`.

- The file's `export default` is an object of handlers, each `async (input, env)` and named for its call. A spot is
  one file: any other `import` or `export` keeps it from loading.
- `input` holds the values of the call, typed by their declaration: a `number` or `duration` is a number, a `bool` a
  boolean, a list an array, and any other value a string. The keys of an item are `input["item.<key>"]`.
- `env` holds each command a spot may call, under its noun and its verb in camelCase, such as `env.timer.add(...)`,
  `env.screen.recordStop()` and `env.toast(...)`. Its arguments are the words of the command in order, an object for
  inputs as `<name>=<value>`, then one object of options, such as `{ dryRun: true }`. It resolves to what the command
  prints, and rejects with its failure line.
- `env.<binding>.<action>(inputs)` [runs a bound spot](#use-another-spot), and resolves to its values, or to `null`
  when the person closes its view. `env.emit(event, values)` [tells other spots](#tell-other-spots), `env.settings`
  holds the settings, and `env.open(id)` opens a spot.
- A handler returns a string, the text of a frame; an array of objects, which `openspot.frame` writes as blocks; an
  object, whose keys become `out.<name>` lines; or nothing. A throw fails the call with its message.
- `openspot.frame(objects)` writes objects as blocks, and an object whose first key is `frame` is the root.
  `openspot.call(words, stdin)` runs any other `openspot` command and returns `{ stdout, code }`.
- It has no files, no network and no process. Openspot waits 2 ms for the frame of a key, and shows a later one at the
  next keystroke.
- A call has 10 seconds of the time its code runs. An `await` counts nothing, and the spot takes other calls while one
  waits, so a handler can wait for the person as long as they take. A loop that never awaits is stopped.
- `openspot types` writes `openspot.d.ts` beside the file. Put `/** @satisfies {import("./openspot").Handlers} */`
  before `export default`, and an editor checks each handler, input, output, event, binding and command.

### A Swift spot

A Swift spot is a program that Openspot builds once and runs at each call. Use it for work that a script does badly;
[Write a spot in Swift](GUIDE.md#write-a-spot-in-swift) shows one.

- A Swift file with `#!/usr/bin/env swift` on its first line is a spot, when the manifest describes it. Each item of
  `source` names one more Swift file, or a folder of them, as a plain path in the spot folder: no `.`, no `..`, and no
  `/` at its start or end.
- Openspot needs the Command Line Tools, and builds again when a file changes. A spot with no `source` runs as a script
  until its build is done, and a failed build is the failure of each call until a file changes.
- It gets the handler's name in `CommandLine.arguments[1]` and the message on stdin, as a script does.
- It starts each `openspot` command with `posix_spawn`, not Foundation's `Process`, which closes descriptor 11 and so
  the link that tells Openspot which spot calls; see [Uses](TRUST.md#uses).
- `openspot types` writes `Openspot.swift` beside the spot: a `Handlers` protocol with a method for each handler,
  typed inputs and outputs, an `Env` of its commands, bindings, `emit` and `open`, and `Openspot.serve`, which reads
  the call, runs its handler and prints its answer, or `error=` for a throw. List it in `source`. Each command it types
  starts `openspot` with `posix_spawn`.
- A shared spot carries the program as `<name>.<hash>.program`, by the SHA-256 of its Swift files. A Mac with no tools
  runs it while the hash matches; see [The review before an add](TRUST.md#the-review-before-an-add).

## Views

A view is a kind of block that a SwiftUI file of the spot draws. Use it for a look or a motion that classes can't give,
such as a chart, a liquid or a game; [Draw your own view](GUIDE.md#draw-your-own-view) shows one.

```ini
box=level
class=relative h-24

liquid=fill
parent=level
value=84
class=absolute inset-0

text=label
parent=level
title=84%
class=self-center font-metric
```

With `views = ["liquid.swift"]` in the manifest, `liquid.swift` draws the block `fill` over the whole box, and the
words 84% show over it, at the top, in the middle.

- Each file of `views` is a kind, named by its file: `views = ["liquid.swift"]` gives `liquid=<id>`. It takes `parent`
  and `class` like any block, and fills the room its classes give it. With no height, it takes the free height, as
  [Layouts](#layouts) says.
- A key of the block can repeat, and `spot.all` reads each value. A file named like a kind of Openspot, such as
  `text.swift`, is a fault, since that kind draws the block.
- The file declares `struct SpotView: View` with `let spot: SpotInput`, with no top-level code and no method
  `update()`.

| Member                                          | Gives                                                                                                       |
| ----------------------------------------------- | ----------------------------------------------------------------------------------------------------------- |
| `spot["key"]`                                   | The last value of a key of its block, or nil. `spot.all("key")` gives each value.                           |
| `spot.size`, `spot.card`                        | The width and height of its area, and the name of its card's size, such as `wide`, or nil off a whole card. |
| `spot.inset`, `spot.corner`                     | The space a card keeps inside its edge, and its corner radius.                                              |
| `spot.ink`, `spot.secondary`, `spot.accent`     | The colour of words, the opacity of a second line, and the accent colour.                                   |
| `spot.font`                                     | The fonts of the cards: `title`, `detail`, `metric` and `value`.                                            |
| `spot.theme`                                    | The values of the theme; [Follow the theme in a view](GUIDE.md#follow-the-theme-in-a-view) lists them.      |
| `spot.send(v)`, `spot.answers`                  | Runs the action that the block's id names, with `v` as `value`, and changes at each answer, to end a busy state. |
| `spot.card(id)`, `spot.cardSize(id)`            | The card of a spot, by the id that `openspot store list` prints, and its size.                              |
| `spot.sheet(id)`                                | The sheet of a spot from its `sample.sh`, where a click runs nothing.                                       |
| `spot.tip(text)`, `spot.tipDelay`               | A tip in the look of Openspot's own, to show on hover, after that delay.                                    |
| `spot.media(path)`                              | A PNG, JPEG or GIF picture, or a MOV or MP4 video, at its size or less.                                     |
| `spot.loop(...)`                                | A shape that moves in a loop, played by macOS.                                                              |
| `spot.cornerButton`                             | The round button on the rim of a card, by its id and an action.                                             |
| `spot.columnGap`, `spot.rowGap`, `spot.columns` | The gaps between cards, and how many columns of cards a window holds.                                       |
| `spot.items`, `spot.selection`                  | Each item of the frame, in a sheet or a window, and the id of the selected one.                             |
| `spot.isShown`                                  | Whether its place shows now. It's false while the panel is hidden.                                          |
| `spot.close()`                                  | Closes the sheet, the float or the window of its own spot.                                                  |

- The view gets the keys of its block in each frame, and keeps its `@State`. On a card, it only draws. In a sheet, it
  takes clicks and keys.
- `SpotMetric(spot, value:, detail:, mark:, onFill:)` draws a big number with its detail and an SF Symbol `mark`.
- `spot.loop(period:fill:path:)` and `spot.loop(period:stroke:width:path:)` draw a shape at each time from 0 to
  `period`, and the shape at `period` equals the one at 0. It plays only while `spot.isShown` is true.
- Openspot removes a view while its place is hidden, unless it reads `spot.isShown`, and then it stops its timers and
  its motion while that is false. It compiles the view at its first show and when the file changes, and a shared spot
  carries it as `<name>.<hash>.view`, used while the hash matches.
- The view runs inside Openspot, so a crash quits Openspot. Do the work in the spot, and only draw in `body`.
  [Stats](app/Help/stats.md) counts each run of its `body`.

## Files in and out

An item can stand for a file that the person drags into another app, and a card can take files dropped on it.

- `file=<path>` makes the item stand for that file, such as `file=/Users/me/Report.pdf`, and the path starts with `/`.
  A drag carries only the files that still exist. When a drag ends in another app, Openspot calls `drag` with an
  `item` input for each item.
- `drop = ["png", "jpg"]` in `[on]` names the files a card takes: extensions, `folder`, or `*`. A drop calls `drop`
  with a `file` input for each path. It waits for the card's running call, opens the sheet of a spot whose Return
  opens it, and the call can select the new item.

## Slash commands

A slash command runs a spot with the text the person typed, in one Return. See
[Run a command with text](GUIDE.md#run-a-command-with-text).

- `command = ["<word>"]` in `[on]` gives the spot its words. Each is a row `/<word>`, and Return on it calls `command`
  with the word as `name` and the rest of the line, the words before and after it, as `text`, even when no text
  follows.
- `/` at the start of a word, with a letter after it, lists the words, the actions with a `title` and the `scope=spot`
  buttons of a sheet whose name matches. `/` alone lists them all. A word that matches none stays text. An action with
  `confirm` isn't listed.
- A first frame whose root has `type=form` is a form, whose values go to the same handler. Other blocks, fields too,
  open the sheet. A frame with nothing to show, or the end of the call, closes the panel.
- The words are the spot's defaults. The person renames or removes each one; see
  [The places of a spot](GUIDE.md#the-places-of-a-spot). `command` still gets the spot's own word as `name`.

## Act at a time

A timer runs an action of its spot at a time the spot chose, such as the end of a snooze, even when the panel is
closed.

```toml
title = "Stretch"
icon = "figure.walk"
uses = ["timer"]

[actions.remind]
inputs.words = { type = "text", required = true }
```

```sh
#!/bin/sh
. "$OPENSPOT_SH"
case "$1" in
  show) printf 'button=later\ntitle=Remind me in an hour\nscope=spot\n' ;;
  later) openspot timer add "$(date -u -v+1H +%Y-%m-%dT%H:%M:%SZ)" remind words="Time to stretch" ;;
  remind) openspot toast "$(value words)" ;;
esac
```

A press of Remind me in an hour adds a timer. An hour later, Openspot calls `stretch remind` with
`input.words=Time to stretch`, and the spot shows the toast Time to stretch.

- `openspot timer add <time> <action> [<name>=<value>...]` takes an ISO 8601 time with its offset, such as
  `2026-11-20T08:00:00+01:00`, the action to run and its inputs, and prints the timer's id. Openspot checks the inputs
  when you add the timer: an unknown action, an undeclared input, a word with no `=`, a wrong type or a missing
  required input exits 2.
- A time that has passed comes due at once, such as after the Mac slept or Openspot was quit, and `someday` keeps a
  timer that never comes due, until `timer remove`. A due timer runs its action as a press that the person didn't make,
  and Openspot draws nothing that the call prints.
- `openspot timer list` prints each timer of the spot as an item, with its action as the `title`, its time in `at`,
  and each input as `input.<name>=`. `openspot timer remove <id>` removes one.
- A timer belongs to the spot that added it, and no other spot sees it. It lasts until it comes due, also across a
  restart. A spot holds at most 1000 timers, each with inputs of at most 4 KB. A timer of a spot that is off or gone
  comes due into nothing.
- For a time that repeats, `schedule` in `[on]` takes cron lines, such as `schedule = ["0 9 * * 1-5"]` for 9:00 on each
  weekday. Openspot calls `schedule` at each time, shown or not, with the line as `cron` and the seconds it came late
  as `late`. A time missed while the Mac slept runs once at wake. A spot with a `schedule` acts by itself, so it starts
  off until the person turns it on.

## Use another spot

A spot can run the action of another spot and wait for its values, such as a picker that several spots share. Name the
other spot in `[bindings]`, then run its action with `openspot run`.

### Let the person pick the time

Snooze, a spot of Openspot, is a grid of big tiles such as Later, Tomorrow and Pick Date. Its action `pick` shows them
and gives the time of the tile that the person picks as `until`.

```toml
title = "Remind me"
icon = "bell"
uses = ["timer"]

[bindings]
picker = { spot = "openspot/snooze" }

[actions.remind]
inputs.words = { type = "text", required = true }
```

```sh
#!/bin/sh
. "$OPENSPOT_SH"
case "$1" in
  show) printf 'button=later\ntitle=Remind me later\nscope=spot\n' ;;
  later)
    until=$(openspot run picker.pick title="Remind me later" --out until) || exit 0
    openspot timer add "$until" remind words="Look at this again"
    ;;
  remind) openspot toast "$(value words)" ;;
esac
```

A press of Remind me later shows Snooze over the sheet, titled Remind me later. A pick prints its time, and the spot
adds a timer. Esc ends the run with exit 4, so the spot adds nothing.

- `until` is an ISO 8601 time with its offset, or `someday` for Someday, which has no time. The person sets the hours
  of the tiles, such as the morning and the evening, in the Settings of Snooze.

### Bindings and runs

- `[bindings]` names each spot that this spot calls or listens to, under a name of its choice with no dot, such as
  `picker = { spot = "openspot/snooze" }`. The person approves each binding at an add, and the spot's page lists them
  beside its uses. A bound spot that isn't installed shows as missing.
- `openspot run <binding>.<action> [<name>=<value>...]` runs the action and waits for its values. It prints them as
  `out.<name>=` lines, or with `--out <name>` each value of that output on a line of its own. `--stdin <name>` reads that
  input from stdin, for a value that is long or has lines.
- It checks the binding, the action and the inputs before the call, and the outputs after it. An undeclared binding, an
  unknown action, an undeclared input or a wrong type exits 2, a bound spot that doesn't load or a failure exits 1 with
  its line, and an action with outputs that gives none exits 3.
- An action that answers with a view shows it over the sheet that shows, as a step of its flow, titled by the `title`
  of its frame's root. The run ends, and the view leaves, at the first frame of the bound spot that holds `out.<name>`
  lines or `error=`. A close or a step back from it exits 4, and in JavaScript resolves to `null`.
- A run that waits for the person or another spot doesn't count against its spot's time limit.
- A handler that the person didn't press, such as `show`, `schedule`, a timer or an event, can still run a bound action,
  but the action can't show a view there: the run exits 2 with a line that says it needs the person. Such a handler
  shows a toast or opens a float instead.
- A run to a spot that is already in its chain, such as A, B, then A, exits 2 and names the chain, and so does a chain
  of more than 4 runs. A press, a key or a form starts a new chain.
- Openspot knows the calling spot only by the link on descriptor 11 of its run, so a process with no link can't use
  `openspot run` or `openspot emit`. See [Uses](TRUST.md#uses).

## Tell other spots

A spot tells the spots that bind it that something happened, with typed values. Declare each event in `[events]`, and
send it with `openspot emit`.

```toml
title = "Focus"
icon = "timer"

[actions.finish]
title = "Finish Focus"

[events.finished]
minutes = { type = "number", required = true }
```

```sh
#!/bin/sh
case "$1" in
  finish) openspot emit finished minutes=25 ;;
esac
```

A spot that binds Focus as `focus = { spot = "focus" }` and lists `"focus.finished" = true` in its `[on]` gets a call
of its handler `focus.finished`, with `input.minutes=25`.

- `[events.<name>]` holds one event, with a name that has no dot, and each of its values takes the shape of an input.
- `openspot emit <event> [<name>=<value>...]` checks the values as `timer add` checks inputs: an undeclared value, a
  missing required one or a wrong type exits 2 and calls no spot.
- Each loaded spot that binds the sender and lists `<binding>.<event>` in its `[on]` gets one call, whether or not the
  panel shows. The call counts as one the person didn't press.
- At load, Openspot checks that the bound spot declares the event, when that spot loads too.

## The life of a call

A call starts, prints and ends. These rules say how long it can take, and what happens when it stops.

```text
start ──► frame ──► frame ──► ... ──► end    exit 0: done; error= or another code: the message shows
  └──► stop: a newer value, a second press or a quit; terminate signal, then kill
```

- A `show` has 10 seconds to print its first frame or end. Other calls have no limit. A wait inside an `openspot`
  command for the person or another spot doesn't count. A frame holds at most 32 MB, and past it the call shows nothing
  more.
- A new value of a block stops the older call of that block, and a second press stops a running call: its process
  group gets the terminate signal, then the kill signal. A stopped call changes nothing.
- A spot's keys run one at a time, in order, and never stop a call. At most 8 presses wait, and a later one is
  dropped. A staying spot gets each press at once, while fewer than 8 calls of its keys are open.
- A handler fails with `error=<message>` in its frame's root, a throw in JavaScript, or an exit code other than 0, and
  the person sees the message or the last line of stderr. A run of it from another spot exits 1 with the message. A
  failure can print `link=<url>`, a web page that helps fix it. A failed show at `panel.open` only marks its card.
- A stop can come at any time, and two calls can run at once. Never leave a file half written.

# Reference

Here are the exact rules, tables and limits, to look up a key, a kind or an event.

## The format

The message, each frame and each report of `openspot` are lines of `key=value`.

```ini
item=wifi
title=Wi-Fi
detail=Home · 82 Mb/s
---
```

- A line splits at its first `=`. A blank line ends a block, and a line `---` ends a frame. In a value, `\n` is a new
  line and `\\` is a backslash. An empty value is no value, and Openspot never splits a value.
- In a frame, Openspot skips a line with an unknown key and a block of an unknown kind, and `openspot check spots`
  reports each one. In the manifest, an unknown key is a fault.

## The manifest

The manifest says what a spot keeps, does, tells, uses, binds and listens to, so that Openspot can list it, check it and
call it. It's the file `spot.toml` in the spot folder.

```toml
title = "Snooze Tab"
icon = "moon.zzz"
uses = ["timer"]

[settings]
browser = { type = "choice", options = ["Safari", "Chrome"], default = "Safari" }

[actions.snooze]
title = "Snooze Tab"
outputs.until = "text"

[actions.wake]
inputs.url = { type = "url", required = true, description = "The tab to open again" }

[events.woke]
url = "url"

[bindings]
picker = { spot = "openspot/snooze" }

[on]
"sheet.open" = true
command = ["snooze"]
```

- The keys at the top describe the spot. A value is a string in quotes, a number, `true` or `false`, a list in
  brackets, or a table in braces. `source`, `views`, `pages`, `uses` and `keywords` take a list.
- A wrong or unknown key, such as `titel`, keeps the spot from loading, and its fault names the key. The keys that only
  Openspot's own spots take are in [The app's own words](spots/AGENTS.md#the-apps-own-words).
- A spot has a sheet unless it has an action with a `title` and no event in `[on]`. Such a spot runs its one action on
  Return, or opens the keys of its actions.
- `openspot schema` prints the JSON Schema of `spot.toml`, and [`schema/spot.schema.json`](schema/spot.schema.json)
  holds a copy. An editor that reads a `#:schema` line at the top of the file, such as one with Taplo, checks each key
  as you type.

| Key        | Value                                                                                                  |
| ---------- | ------------------------------------------------------------------------------------------------------ |
| `title`    | The name. By default, the file name.                                                                   |
| `icon`     | The icon, as in a [block](#blocks). A path that doesn't start with `/` starts at the spot folder.      |
| `detail`   | The line under the title.                                                                              |
| `keywords` | More words that find the spot in the main search.                                                      |
| `uses`     | The features of the Mac that the spot uses, such as `network` or `screen`. [Uses](TRUST.md#uses) lists each one. |
| `views`    | SwiftUI files in the spot folder, each a kind of block, such as `["liquid.swift"]` for `liquid=<id>`. See [Views](#views). |
| `source`   | The Swift files, or folders of them, that a [Swift spot](#a-swift-spot) is built with.                 |
| `stay`     | `true` keeps one process for every call. See [Modes](#modes).                                          |
| `answers`  | `last`: the answers of `search` show under the other results, not first. `card`: they show as one card. |

| Table              | Meaning                                                                                                   |
| ------------------ | --------------------------------------------------------------------------------------------------------- |
| `[settings]`       | One key for each [setting](#settings), with its type, `title`, `icon`, `default`, `description` and `options`. |
| `[actions.<id>]`   | An [action](#actions): `title`, `icon`, `confirm`, and `inputs.<name>` and `outputs.<name>`, each with a type. |
| `[events.<name>]`  | An event that the spot [tells other spots](#tell-other-spots), with a type for each of its values.         |
| `[bindings]`       | One key for each spot that it [uses](#use-another-spot), as `<name> = { spot = "<id>" }`.                  |
| `[on]`             | The [triggers](#triggers) that call the spot by themselves, each with its filter.                         |

## Triggers

Each key of `[on]`, the handler it calls and its filter.

| Key                   | Calls               | Takes                                                                                 |
| --------------------- | ------------------- | ------------------------------------------------------------------------------------- |
| `command`             | `command`           | A list of words, such as `["snooze"]`. See [Slash commands](#slash-commands).         |
| `search`              | `search`            | A regular expression of the main search, or `true` to list the items of `show` there. See [The main search](#the-main-search). |
| `schedule`            | `schedule`          | A list of cron lines: minute, hour, day, month and weekday. See [Act at a time](#act-at-a-time). |
| `every`               | `every`             | A whole number of seconds. See [Listen for events](#listen-for-events).               |
| `drop`                | `drop`              | A list of file types. See [Files in and out](#files-in-and-out).                      |
| `"<event>"`           | `show` or `<event>` | `true`, or a regular expression of its value. [Events](#events) lists each one.       |
| `"<binding>.<event>"` | `<binding>.<event>` | `true`. See [Tell other spots](#tell-other-spots).                                    |

## Types

Each input, output, setting and value of an event has one of these types.

| Type       | Value                                                                       |
| ---------- | --------------------------------------------------------------------------- |
| `text`     | Any text.                                                                   |
| `number`   | A number, such as `4` or `2.5`.                                             |
| `bool`     | `true` or `false`.                                                          |
| `date`     | An ISO 8601 day or time, such as `2026-11-22` or `2026-11-22T09:00:00Z`.     |
| `duration` | A number of seconds.                                                        |
| `url`      | A web address.                                                              |
| `file`     | A path that starts with `/`.                                                |
| `secret`   | A text of 8 characters or more that Openspot keeps in the Keychain.         |
| `choice`   | One of its `options`.                                                       |
| `[<type>]` | A list of values of that type, such as `[file]`, with one line each. It takes no `default`. |

- A type alone, such as `url = "url"`, is a value that may be empty. A table adds `required = true`, a `default`, a
  `description`, which the drawn form shows as a placeholder, and `options` for a `choice`.

## The message

Each key that a call can find on its stdin.

| Key                 | Holds                                                                                                  |
| ------------------- | ------------------------------------------------------------------------------------------------------ |
| `input.<name>=`     | Each input of the call: the inputs of an action, and the values that [The calls](#the-calls) lists, such as `item`, `value` or `text`. Each field of the sheet or of a form comes as `input.<id>=`. |
| `input.item.<key>=` | On a press or an action of an item that holds a key of its own, each key of the item.                  |
| `input.route=`      | The [route](#pages) of the sheet that shows. The first sheet of a spot has none.                       |
| `setting.<name>=`   | Each [setting](#settings), or its default, but a secret.                                               |

## Blocks

Each kind of block, the keys of its own and the call it makes.

| Kind              | Shows                                                                                                            | Its own keys                                                                      | Calls                          |
| ----------------- | ---------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------- | ------------------------------ |
| `box`             | The blocks inside it, laid out by its classes, or inside `items` a group of items under its `title`.             |                                                                                   |                                |
| `text`            | Words.                                                                                                           | `value`                                                                           |                                |
| `item`            | A row of a list: its title and detail. See [Items](#items).                                                      | `value` and the keys of [Items](#items)                                           | `press`, with `item`           |
| `icon`            | The icon of its `value`, by the rules of `icon` below.                                                           | `value`                                                                           |                                |
| `picture`         | An image that fills its area.                                                                                    | `icon`                                                                            |                                |
| `number`          | One `value` as text, a ring or a bar, with its `title` as the label. See [Show a number](#show-a-number).         | `value`, `max`, `unit`, `display`, `type`                                         |                                |
| `series`          | Points over time, a bar for each, under the last value. See [Show a series](#show-a-series), with `add` and `keep`. | `value`, `max`, `unit`, `display`                                                 |                                |
| `button`          | A button, or a row of the ⌘K menu (see [Buttons and actions](#buttons-and-actions)). The blocks inside it are its look. | `shortcut`, `confirm`, `close`, `scope`                                     | `<id>`, with `item`            |
| `field`           | A text field, or another input with a `type`.                                                                    | `value`, `type`, `placeholder`, `required`, `readonly`, `min`, `max`, `recording` | `<id>`, with `value`           |
| `switch`          | A switch, or with `type=tick` a round tick before its words, for a thing to do.                                  | `value`: `true` or `false`, `type`                                                | `<id>`, with `value`           |
| `choice`          | A menu of the `option` blocks after it, or another form with a `type`.                                           | `color`, `value`, `type`                                                          | `<id>`, with the option as `value` |
| `option`          | One option of the `choice` right before it.                                                                      | `title`, `icon`                                                                   |                                |
| `items`           | The [items](#items): the blocks inside it are the items, and a `button` there is a row of the ⌘K menu.           |                                                                                   |                                |
| A view of a spot  | What its SwiftUI file draws, named by the file (see [Views](#views)).                                            | any key the view reads                                                            | `<id>`, with `value`           |

- Every kind also takes `parent`, `class` and `grow`, which place it in the [layout](#layouts), and `title`, `detail`,
  `tone` and `icon`. `tone` is `good`, `warn` or `bad`, and colours the detail, or the title with no detail.
  `color=#RRGGBB` on a text or a number draws a bar of that colour at its edge.
- `icon` is an image file, such as `cups.png`; an `https://` image, downloaded once; the Finder icon of a path with a
  `/` or a leading `~`; an SF Symbol, such as `wifi`; or any other text, such as `😀`. It draws the same on every kind
  and in every place, before the title.
- A field's `type`: none for one line, `multiline` for several lines, which takes the free height, `slider` from `min`
  to `max`, 0 to 100 by default, which sends a whole number, `search` for the search field of the [items](#items), and
  `hotkey`.
- A choice's `type`: none for a menu, `list` for a list of its options, `swatches` for a swatch of each of its `color`
  lines, which sends the colour, and `multiple`, in a form, for several options.
- A `hotkey` field shows keycaps, and records a key at Return or a click on it, or when a new frame gives it
  `recording=true`. Every key goes to it, Esc brings back its key, and a shortcut runs its action with the key as
  `value`. While a sheet with one shows, Openspot's own keys are off.

## Classes

A class styles a block, and its name is the one Tailwind CSS gives it. Every size and colour comes from the theme.

```ini
box=row
class=flex-row items-center gap-2 p-3 bg-tile rounded-inner

text=name
parent=row
title=Home Network of the Whole Family
class=grow font-semibold text-accent truncate

text=speed
parent=row
title=82 Mb/s
class=text-secondary tabular-nums
```

A tile with round corners holds one row. The name, heavier and in the accent colour, takes the free width and ends in
… where it doesn't fit, and 82 Mb/s sits at the end in the second colour of words.

| Group     | Classes                                                                                                                                                       |
| --------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Layout    | `flex-col`, `flex-row`, `grid`, `grid-cols-<n>`, `col-span-<n>`, `row-span-<n>`, `relative`, `absolute`, `inset-0`, `top-0`, `right-0`, `bottom-0`, `left-0`, `hidden`, `flex` |
| Alignment | `items-start`, `items-center`, `items-end`, `items-stretch`, `justify-start`, `justify-center`, `justify-end`, `justify-between`, `self-start`, `self-center`, `self-end`, `self-stretch` |
| Space     | `p-<s>`, `px-<s>`, `py-<s>`, `pt-<s>`, `pr-<s>`, `pb-<s>`, `pl-<s>`, `gap-<s>`, `gap-x-<s>`, `gap-y-<s>`                                                       |
| Size      | `w-<s>`, `h-<s>`, `size-<s>`, `min-w-<s>`, `max-w-<s>`, `grow`, `shrink-0`, `aspect-square`                                                                    |
| Words     | `font-title`, `font-detail`, `font-metric`, `font-value`, `font-section`, `font-medium`, `font-semibold`, `font-bold`, `text-left`, `text-center`, `text-right`, `truncate`, `line-clamp-<n>`, `tabular-nums`, `sr-only` |
| Colour    | `text-ink`, `text-secondary`, `text-accent`, `text-good`, `text-warn`, `text-bad`, `bg-tile`, `bg-accent`, `bg-good`, `bg-warn`, `bg-bad`, `bg-transparent`, `backdrop-blur`, `opacity-<p>` |
| Shape     | `rounded-card`, `rounded-inner`, `rounded-full`, `rounded-none`, `border`, `overflow-hidden`                                                                   |

- `<s>` is a step of Tailwind's scale from `0` to `96`, such as `3` or `0.5`, and each step is 4 points. `part` and
  `group` are the gaps of Openspot's own sheets, as in `gap-part`.
- A size also takes `full`, the whole width or height of its box, a share such as `1/2`, `1/3`, `2/3`, `1/4` or `3/4`,
  and `px`, the height of a divider.
- `<n>` is a count from 1 to 12, and `<p>` a percent from 0 to 100 in steps of 5.
- `flex` shows a block that `hidden` hides, such as `hidden card:flex`.
- `font-section` gives a `text` the look of a title over a group of blocks.
- On a `button`, a `field`, a `switch`, a `choice`, a `number` or a `series`, a class chooses the box that Openspot draws for it:
  `bg-accent` is the one main button, `bg-tile` a tile, `bg-transparent` no box, and `rounded-full` on a button a chip
  as wide as its words, or a round button of its `icon` when it has no `title`.
- A block smaller than its box takes its place from `self-start`, `self-center` or `self-end`, or from `text-left`,
  `text-center` or `text-right` inside its own area.
- `backdrop-blur` blurs what lies under the block with the material of the Mac. No class draws glass.
- A class that isn't here is skipped, and `openspot check spots` reports it. A free value, such as `w-[120px]`, is
  such a class.

## Variants

A variant applies a class only in a place or a state, as Tailwind's `hover:` does. Openspot applies it with no call to
the spot.

```ini
button=play
title=Play
class=bg-tile hover:bg-accent card:hidden
```

In the sheet, Play is a tile, and it becomes the main button while the pointer is over it. A card doesn't show it.

| Prefix                                           | Applies                                                                                  |
| ------------------------------------------------ | ---------------------------------------------------------------------------------------- |
| `sheet:`, `card:`, `bar:`, `float:`, `window:`    | In that [place](#places). `card:` is any card.                                           |
| `small:`, `wide:`, `square:`, `strip:`, `large:` | On a card of that size.                                                                  |
| `hover:`, `pressed:`, `selected:`, `focus:`      | While the pointer is over it, it's pressed, its item is selected, or it has the keys.    |
| `dark:`, `light:`                                | In that appearance of the Mac.                                                           |

- Prefixes combine, such as `card:hover:bg-tile`, and the class then applies only when each of them does.
- A class with more prefixes wins over one with fewer, and a class with a prefix wins over the same class with none.
- The blocks inside a `button` take its `hover:`, `pressed:`, `selected:` and `focus:`.

## Events

Each event that Openspot raises, when it raises it, and the value that its handler gets as the input `value`. Each is a
key of `[on]`; see [Listen for events](#listen-for-events).

| Event              | When Openspot raises it                                                              | Value                            |
| ------------------ | ------------------------------------------------------------------------------------ | -------------------------------- |
| `sheet.open`       | When the spot's sheet opens. List it to call `show` again within 5 seconds, or to give a spot with actions a sheet. |                                  |
| `panel.open`       | Each time the panel opens, and once when Openspot starts.                            |                                  |
| `sheet.text`       | At each change of the sheet's search text, and when the sheet opens.                 | the text                         |
| `spot.want`        | When the spot first shows in a panel open: its card on the grid, or its rows in the main search. |                                  |
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
an old spot raises the major number: `3.0` lays out every place with the tree of [Layouts](#layouts), in place of the
`grid=` lines, the `repeat`, the `section`, the `view`, the `look` and the `align` of `2.0`, and calls a handler named
for each trigger, with typed inputs, as [The calls](#the-calls) says.

## How to extend

An old spot never sees a word it didn't ask for. An older Openspot skips a word of a frame that it doesn't know, and
doesn't load a spot whose manifest has a key that it doesn't know.

| To add               | Add                                                                       |
| -------------------- | ------------------------------------------------------------------------- |
| A thing that happens | an event `<noun>.<verb>`, a key of `[on]` and a handler of its name       |
| A place to show      | a variant `<place>:`                                                      |
| A look or a layout   | a class                                                                   |
| A thing to draw      | a kind `<kind>=`, which an older Openspot skips and reports               |
| A detail of a kind   | a key, or a `type` value                                                  |
| A power of the Mac   | a noun: `openspot <noun> <verb>`, its events and its `uses` word          |
| A complex look       | nothing: a [view](#views) of the spot                                     |
