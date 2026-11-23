# A spot

`draft` `required`

A spot is a small tool that Openspot shows in its panel. It's a folder with a `spot.toml` and a script: Openspot runs
the script, and the script prints what to show. This page is everything a spot needs. Each later page adds one
capability on top of it.

```text
ports.spot/
  spot.toml
  ports.sh
```

## The folder

Put the folder in `~/.config/openspot/spots`, and make the script executable with `chmod +x`. Openspot loads the spot a
moment later, and its card shows in the panel.

| File             | Required | Is                                                                          |
| ---------------- | -------- | --------------------------------------------------------------------------- |
| `spot.toml`      | yes      | The name and icon of the spot, and the capabilities it adds.                |
| `<name>.<ext>`   | yes      | The script, named like the folder, such as `ports.sh` or `ports.js`.        |
| `readme.md`      | no       | The page that the Store shows about the spot.                               |
| `sample.sh`      | no       | A script that prints what the spot shows, with made-up data.                |
| `releases.jsonl` | no       | The signed releases; see [Signed releases](../../TRUST.md#signed-releases). |

- The id of a spot is the name of its folder without `.spot`, such as `ports`.
- A spot folder must hold 25 MB or less.

## spot.toml

`spot.toml` names your spot. Two keys are enough:

```toml
title = "Ports"
icon = "network"
```

| Key        | Type   | Default           | Is                                                          |
| ---------- | ------ | ----------------- | ----------------------------------------------------------- |
| `title`    | text   | the folder's name | The name of the spot.                                       |
| `icon`     | text   | none              | An SF Symbol, an emoji, or an image file of the folder.     |
| `detail`   | text   | none              | The line under the title.                                   |
| `keywords` | [text] | none              | More words that find the spot in the panel's search.        |

- Each other key and table comes with the page of its capability, and [the index](../../PROTOCOL.md#spottoml) lists
  them all.
- A wrong or unknown key, such as `titel`, keeps the spot from loading, and its fault names the key.
- `openspot schema` prints the JSON Schema of the file, and [`schema/spot.schema.json`](../../schema/spot.schema.json)
  holds a copy, so an editor such as one with Taplo can check it as you type.

## The calls

Each time Openspot needs your spot, it runs the script once. That run is a call. The first argument names the handler,
the part of the script that answers, and stdin holds the inputs, one `key=value` line each:

```text
ports.sh press
```

```ini
input.item=4120
input.item.port=:3000
setting.signal=TERM
```

| Call           | Comes                                                                    | Inputs               |
| -------------- | ------------------------------------------------------------------------ | -------------------- |
| `<spot> show`  | When its sheet opens, or a card or the menu bar needs it.                | `event`, `route`     |
| `<spot> press` | When the person presses an item, or the card of a spot with no sheet.    | `item`, `item.<key>` |

Every other handler comes with a capability, and [the index](../../PROTOCOL.md#handlers) lists them all. A script
ignores a handler it doesn't know.

- `show` is a read, and so is each handler that only asks what to show. A read MUST NOT change anything or open
  anything.
- `input.<name>=` is one input, such as `item`. `input.item.<key>=` is a key of the pressed item's own, such as
  `port`. `setting.<name>=` is one [setting](07-settings.md), or its default.

Each call gets these variables:

| Variable        | Is                                                                |
| --------------- | ----------------------------------------------------------------- |
| `OPENSPOT_ID`   | The id of the spot.                                               |
| `OPENSPOT_DATA` | The folder where the spot keeps what lasts.                       |
| `OPENSPOT_SH`   | The path of the shell helper.                                     |
| `PATH`          | The `openspot` command, then the person's paths and the system's. |
| `LC_ALL`        | `en_US.UTF-8`.                                                    |

## The shell helper

`. "$OPENSPOT_SH"` loads functions that read stdin once and print values safely. Once it's loaded, read stdin only with
`value` or `openspot_input`, never with `cat`.

| Function                                     | Does                                                                              |
| -------------------------------------------- | --------------------------------------------------------------------------------- |
| `value <name>`                               | Prints each value of an input, or of a line such as `setting.city`.               |
| `openspot_input`                             | Prints stdin as it came.                                                          |
| `openspot_item <id> <title> [detail] [icon]` | Prints a blank line, then one `item` block, so it starts a new block.             |
| `openspot_items [kind]`                      | Prints a block for each line of stdin: id, title, detail and icon, split by tabs. |
| `openspot_kv <key> <value>`                  | Prints one more line of the block above it.                                       |
| `esc <text>`                                 | Prints a text as a value.                                                         |
| `openspot_value <key> <text>`                | Prints each value of a key in a text, such as what a command printed.             |
| `openspot_rows <key>...`                     | Prints a line of tab-separated values for each block of stdin.                    |
| `openspot_keep <file> [text]`                | Writes the text, or stdin, to the file at once, so a stop never leaves half of it. |
| `openspot_paste <text>`                      | Pastes the text into the front app, with `clipboard` in `uses`.                   |
| `openspot_serve <function> "$@"`             | Runs the function at each call; see [A staying spot](11-modes.md#a-staying-spot). |

## Frames

Your script answers on stdout with a frame: the lines that say what to show. A frame is made of blocks of `key=value`
lines, and a blank line ends each block.

```ini
frame=
title=Ports
detail=2 listening

item=4120
title=:3000
detail=node

item=812
title=:5432
detail=postgres
```

- A line splits at its first `=`.
- In a value, `\n` is a new line and `\\` is a backslash. An empty value is no value.
- A value that comes from data MUST be printed with `openspot_item`, `openspot_kv` or `esc`, so that it can't add a
  line or a block.

### Blocks

A block is one thing that a frame shows. Its first line is its kind and its id, such as `item=4120`, and the id names
the block and the handler it calls. These keys work on every block:

| Key      | Type    | Is                                                          |
| -------- | ------- | ----------------------------------------------------------- |
| `title`  | text    | The first line of the block's words.                        |
| `detail` | text    | The line under the title.                                   |
| `icon`   | text    | An SF Symbol, an emoji, an image file or a web image.       |
| `tone`   | text    | The colour of the words: `good`, `warn` or `bad`.           |
| `parent` | id      | The block that this block sits inside.                      |
| `class`  | classes | The [classes](04-layouts.md#classes) that place and style it. |
| `grow`   | bool    | Whether the block takes the free height of its box.         |

- An `item` is a row of the list. A frame of items shows as a list that the person searches, and a press of a row
  calls `press` with its id as the input `item`.
- A key of an item's own, such as `port=:3000`, comes back as `input.item.port=` when the person presses it.
- `openspot check spots` reports an unknown key, kind or class, and Openspot skips it. Each other kind of block is in
  [the index](../../PROTOCOL.md#block-kinds).

### The root

The root is the block of the frame's own keys. It starts with `frame=` or `error=`, comes first, and isn't drawn.

| Key        | Type           | Is                                                         |
| ---------- | -------------- | ---------------------------------------------------------- |
| `frame`    | text           | The route of the sheet that the frame is for, often empty. |
| `title`    | text           | The title of the card.                                     |
| `detail`   | text           | The line under the card's title.                           |
| `progress` | number, 0 to 1 | How much of the call's work is done.                       |
| `error`    | text           | The message of a failure of the call.                      |

Other root keys come with their capability, and [the index](../../PROTOCOL.md#root-keys) lists them.

### More than one frame

A line `---` ends a frame, so one call can print several, such as one at each step of its work. Openspot draws each
frame as soon as it arrives.

- The first frame of a call replaces what shows, and so does a later frame with a `frame=` line.
- A later frame with no `frame=` line changes only the blocks it prints. A block with the id of one that shows changes
  only the keys it prints, and a block with a new id joins the end.
- If a `show` prints nothing, the spot shows nothing.

## How a call ends

A call starts, prints frames and ends. It can be stopped at any time.

```text
start ──► frame ──► frame ──► end    exit 0: done; error= or another code: the message shows
  └──► stop: a newer value, a second press or a quit
```

- A `show` has 10 seconds to print its first frame. Other calls have no limit.
- A handler fails with `error=<message>` in its frame, or with an exit code other than 0. The person sees the message,
  or the last line of stderr. `link=<url>` adds a page that helps fix it.
- A call that answers with no view closes the panel. With `close=false` on the pressed block, the panel stays open, and
  Openspot calls `show` again.
- A stop sends the terminate signal, then the kill signal, to the call's processes. A spot MUST NOT leave a file half
  written, so write with `openspot_keep`.
- A process that your script starts gets its stdin, unless the helper read it first, so close it, as in
  `curl "$url" </dev/null`.

### Write a message

A toast or a failure line tells the person what happened and what to do next.

- Instead of `Oops! Something went wrong.`, write `Openspot cannot find a screenshot.`
- Instead of `Error 1: osascript failed.`, write ``Copied, but Openspot cannot paste. Press `⌘V`, or allow Openspot in
  Accessibility.``

Say what still worked, and the step that fixes the rest, in one or two calm sentences. Put each key in backticks.

## Try your spot

You can run one call the way Openspot does, and see what it prints:

```sh
openspot spot run ports show
openspot check spots ~/.config/openspot/spots
openspot spot log ports
```

`spot run` prints the frame. `check spots` prints nothing when each spot loads and runs, or a `fault` block for each
error. `spot log` prints the last calls, with their stdin, stdout, stderr and exit code. And
`openspot playground open ports.spot/ports.sh` shows the spot in a panel of its own, and runs it again each time you
save.

## Ports, the whole spot

Ports lists each process that listens on a port, and stops the one you press, such as a server that's still on :3000.

`ports.spot/spot.toml`:

```toml
title = "Ports"
icon = "network"
```

`ports.spot/ports.sh`:

```sh
#!/bin/sh
. "$OPENSPOT_SH"
case "$1" in
  show)
    lsof -nP -iTCP -sTCP:LISTEN | awk 'NR > 1 && !seen[$2]++ {
      sub(/.*:/, ":", $9)
      print $2 "\t" $9 "\t" $1
    }' | openspot_items
    ;;
  press) kill "$(value item)" ;;
esac
```

The sheet of Ports lists a row for each process that listens, with its port as the title and its name under it. When
you press Return on a row, `press` gets the process id as `item`, the process stops, and the panel closes.
