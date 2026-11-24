# What your script prints

Your script prints blocks of `key=value` lines on stdout, and Openspot draws them.

```ini
frame=
title=Ports
detail=2 listening

item=4120
title=:3000
detail=node
```

## Lines

How Openspot reads what you print.

| Rule                 | Is                                                                                  |
| -------------------- | ----------------------------------------------------------------------------------- |
| `key=value`          | One line. It splits at the first `=`.                                               |
| A blank line         | Ends a block.                                                                       |
| `\n` and `\\`        | A new line and a backslash inside a value. `esc` of the shell helper writes them.  |
| An empty value       | No value.                                                                           |
| The same key again   | One more value, such as each `value=` of a chart.                                   |
| `---`                | Ends a frame. Openspot draws each frame as it comes.                                |

The first frame replaces what shows, and so does a later one that starts with `frame=`. A later frame without it
changes only the blocks it prints: a known id changes only the keys it prints, and a new id joins the end.

A value that comes from data, such as a file name, must not add a line. Print it with `esc` or `openspot_kv` of the
[shell helper](#the-shell-helper), or make sure it holds no new line.

## How a run ends

`show` has 10 seconds to print its first block, or Openspot stops it. Other runs have no limit.

A run fails when it prints `error=` or exits with a code other than 0. People see the `error` message, or else the last
line your script wrote to stderr. When `show` prints nothing, the sheet says Nothing here yet.

A program your script starts reads the script's stdin. Close it with `</dev/null`, as in `curl "$url" </dev/null`.

## The first block

A block that starts with `frame=` or `error=` holds the frame's own keys. It comes first, and it isn't drawn.

| Key          | Is                                                                                   |
| ------------ | ------------------------------------------------------------------------------------ |
| `frame`      | The route of the page the frame is for, empty for the first sheet.                   |
| `error`      | A failure, with its message. People see the message.                                 |
| `title`      | The title of the card.                                                               |
| `detail`     | The line under the card's title.                                                     |
| `class`      | The classes of the whole sheet. With it, the frame has a layout.                     |
| `value`      | The id of the block that the card and the menu bar show, when there's more than one. |
| `active`     | `true` when your spot's thing is on, such as a timer that runs.                      |
| `recents`    | `false` keeps the order you print, instead of the rows pressed last first.           |
| `progress`   | How much of the work is done, from 0 to 1.                                           |
| `type`       | `form`: the frame asks for values, and sends them back to the same word.             |
| `out.<name>` | A value that an action gives back.                                                   |

A script that fails can also print a line `link=<url>`, a page that helps people fix it.

## Kinds of block

A block's first line is its kind and its id, such as `item=4120`.

| Kind      | Is                                     | Its own keys                                                         |
| --------- | -------------------------------------- | -------------------------------------------------------------------- |
| `item`    | A row of the list. A press runs `press`. | See [Items](#items).                                                |
| `items`   | The list itself, in a frame with a layout. | none                                                             |
| `box`     | A box that lays out the blocks whose `parent` names it. | none                                                |
| `text`    | Words.                                 | `value`, the value on a card; `color`, a `#rrggbb` bar at its edge.  |
| `number`  | One value.                             | `value`; `max`, a full ring or bar; `unit`, as in `84%`; `display`, words in place of the value; `type`, `ring` or `bar`. |
| `series`  | Points over time, a bar each.          | `value`, points split by commas, `-` for a gap; `add`, points after the last; `keep`, the most it holds, 60 by default and 600 at most; `max`, `unit`, `display`. |
| `icon`    | An icon alone.                         | `value`, the icon.                                                   |
| `picture` | An image that fills its room.          | `icon`, the image.                                                   |
| `button`  | A verb people press. A press runs the button's id. | `scope`, `item` or `spot` in the ⌘K menu; `shortcut`, such as `cmd+r`; `confirm`, words that ask for a second press; `wait`, what the sheet's foot says while its form waits, such as Reading the page. |
| `field`   | A text people type.                    | `value`; `type`, `multiline`, `slider`, `search` or `hotkey`; `placeholder`; `required`; `readonly`; `min` and `max` of a slider, 0 and 100 by default; `recording`, while a `hotkey` records. |
| `switch`  | On or off.                             | `value`, `true` or `false`; `type`, `tick` for a round tick.         |
| `choice`  | A menu of the `option` blocks after it. | `value`, the chosen id; `type`, `list`, `swatches` or `multiple`; `color`, one colour of `swatches`. |
| `option`  | One choice of a `choice`.              | `title`, its id by default; `icon`; `send`, `true` sends the form when it's chosen; `remove`, `true` lets `⌘⌫` delete it. |
| A view    | A block your SwiftUI file draws, named by the file, such as `week=`. | Any key; see [Draw your own view](../further/views.md). |

A `field`, `switch` or `choice` runs its id with its new value as `value`. A text field sends as people type, and a
slider as they drag. A `search` field searches the items. A switch or a choice closes the panel only with `close=true`.

A button is a row of the ⌘K menu when it has a `scope`, sits inside the `items` block, or is in a frame with no
layout. Anywhere else, it draws where the layout puts it. `button=press` names Return, and its `title` shows in the
footer.

## Keys of every block

| Key      | Is                                                                    |
| -------- | --------------------------------------------------------------------- |
| `title`  | The first line of its words.                                          |
| `detail` | The line under the title.                                             |
| `icon`   | An SF Symbol, an emoji, an image file or a web image.                 |
| `tone`   | `good`, `warn` or `bad`: the colour of its words, or a dot on an item's icon. |
| `parent` | The id of the box or list it sits in.                                 |
| `class`  | Its [classes](classes.md).                                            |
| `grow`   | `true` takes the free height of its box.                              |
| `close`  | Whether a press that shows nothing closes the panel.                  |

## Items

| Key             | Is                                                                        |
| --------------- | ------------------------------------------------------------------------- |
| `title`         | The first line of the row, the id by default.                             |
| `detail`        | The line under the title.                                                 |
| `icon`, `tone`  | The icon of the row, and a dot of its colour.                             |
| `value`         | `true` shows a checkmark.                                                 |
| `keywords`      | Words that find the row but don't show, split by commas.                  |
| `place`         | Where the row sits in your spot, which the panel's search shows.          |
| `pin`           | `top` or `bottom`: the edge the row stays at while the rest scroll.       |
| `hides`         | A button of the ⌘K menu the row doesn't offer, one line each.             |
| `file`          | The file the row stands for, which people can drag out. Dragging runs `drag`. |
| `close`         | `false` keeps the panel open after a press.                               |
| `shake`         | `true` lets a shake be the key the row records.                           |
| `open.title`    | The words of Return on this row.                                          |
| `chosen`        | The value a press of the row picks, at its end with ⌃⌄.                    |
| `open.wait`     | What the sheet's foot says while a press of the row waits, such as Reading the page. |
| `route`         | The page a press opens, with no run of `press`.                           |
| `route.title`   | The title of that page, the row's title by default.                       |
| `route.replace` | `true` replaces the sheet that shows.                                     |

Any other key, such as `path=`, is the row's own, and comes back as `input.item.path=` when people press it.

## What each word gets

Openspot runs your script with a word, such as `ports.sh press`, and sends its inputs on stdin as `input.<name>=`
lines, then your settings as `setting.<name>=` lines.

| Word                 | Comes                                              | Inputs                                               |
| -------------------- | -------------------------------------------------- | ---------------------------------------------------- |
| `show`               | When Openspot needs what to show.                  | `event`: `panel.open`, `sheet.open`, `spot.want` or `spot.change`; `route`, the page, empty for the first. |
| `press`              | When people press a row.                           | `item`, and `item.<key>` for each key of the row; `search`, the text of the sheet's search, on a row with `pin=top`. |
| `drag`               | When people drag rows that have a `file` out.      | `item`, once for each row.                           |
| `search`             | At each text of the panel's search that matches.   | `text`; `alt`, the texts people may have meant, such as in another keyboard layout. |
| `every`              | Each `every` seconds.                              | none                                                 |
| `schedule`           | At each cron line.                                 | `cron`, the line; `late`, the seconds since it was due. |
| `command`            | At `/<word>` in the panel's search.                | `name`, the word; `text`, the rest of the line.      |
| `drop`               | When people drop files on your card.               | `file`, once for each file.                          |
| `<event>`            | When an event of `[on]` comes.                     | `value`, the event's value.                          |
| `sheet.text`         | At each change of your sheet's search field.       | `value`, the text; `alt`.                            |
| `<binding>.<event>`  | When a spot you bind sends the event.              | The event's values.                                  |
| `<action>`           | When people, a timer or another spot run it.       | Its inputs, and `item` from a row.                   |
| `<button>`           | When people press the button.                      | `item`, the selected row, from the ⌘K menu.          |
| `<field>`, `<switch>`, `<choice>` | When its value changes.               | `value`, the new value.                              |
| `<setting>`          | When people press Return on a setting that isn't a `secret` and has no `options`. | none              |

## Environment variables

| Variable          | Is                                                                 |
| ----------------- | ------------------------------------------------------------------ |
| `OPENSPOT_ID`     | The id of your spot.                                               |
| `OPENSPOT_DATA`   | The folder where your spot keeps what lasts.                       |
| `OPENSPOT_SH`     | The path of the shell helper.                                      |
| `PATH`            | The folder of the `openspot` command, then the `PATH` Openspot started with, then `/opt/homebrew/bin`, `/usr/local/bin`, `/usr/bin`, `/bin`, `/usr/sbin` and `/sbin`. Your login shell's paths aren't on it. |
| `LC_ALL`          | `en_US.UTF-8`.                                                     |

## The shell helper

`. "$OPENSPOT_SH"` reads stdin once and gives these functions. Once it's loaded, read stdin only with `value` or
`openspot_input`.

| Function                                     | Does                                                                          |
| -------------------------------------------- | ----------------------------------------------------------------------------- |
| `value <name>`                               | Prints each value of an input, such as `value item`, or of a line, such as `value setting.city`. |
| `openspot_input`                             | Prints stdin as it came.                                                      |
| `esc <text>`                                 | Prints a text as one value, with `\n` and `\\`.                               |
| `openspot_kv <key> <value>`                  | Prints one line, with its value escaped.                                      |
| `openspot_item <id> <title> [detail] [icon]` | Prints a blank line, then one `item` block.                                   |
| `openspot_items [kind]`                      | Prints a block for each line of stdin: id, title, detail and icon, split by tabs. |
| `openspot_value <key> <text>`                | Prints each value of a key in a text, such as what a command printed.         |
| `openspot_rows <key>...`                     | Prints a line of tab-separated values for each block of stdin.                |
| `openspot_keep <file> [text]`                | Writes the text, or stdin, to the file whole, so a stop never leaves half of it. |
| `openspot_paste <text>`                      | Pastes the text into the front app. It needs `clipboard` in `uses`.           |
| `openspot_serve <function> "$@"`             | Runs the function for each word; see [Keep your spot running](../further/staying.md). |
