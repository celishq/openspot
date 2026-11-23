# The calls

Openspot calls a spot with the name of a handler as the first argument and the inputs on stdin, and reads frames from
stdout.

```text
ports.sh press
```

```ini
input.item=4120
input.item.port=:3000
setting.signal=TERM
```

| Call                       | Comes                                                                | Inputs                       |
| -------------------------- | -------------------------------------------------------------------- | ---------------------------- |
| `<spot> show`              | When its sheet opens, or a card or the menu bar needs it.            | `event`, `route`             |
| `<spot> press`             | When the person presses an item, or the card of a spot with no sheet. | `item`, `item.<key>`         |
| `<spot> <action>`          | When an [action](07-actions-and-settings.md#actionsid) runs, or a block with its id is pressed or changed. | its inputs, `item` or `value` |
| `<spot> command`           | When the person runs a [slash command](08-triggers.md#slash-commands). | `name`, `text`               |
| `<spot> search`            | When a text of the panel's search matches `search` in `[on]`.        | `text`, `alt`                |
| `<spot> every`             | Every `every` seconds of `[on]` while the spot shows.                | none                         |
| `<spot> schedule`          | At each time of `schedule` in `[on]`.                                | `cron`, `late`               |
| `<spot> drop`              | When the person drops files on its card.                             | `file`, once for each path   |
| `<spot> drag`              | When the person drags items that stand for files out of its sheet.   | `item`, once for each item   |
| `<spot> <event>`           | When an [event](08-triggers.md#events) of `[on]` comes.              | `value`                      |
| `<spot> <binding>.<event>` | When a spot that it [binds](09-bindings-and-events.md) sends the event. | the event's values         |

- `show`, `search`, `every` and an event's handler are reads. A read MUST NOT change anything or open anything.
- A call that answers with no view closes the panel. With `close=false` on the pressed block, the panel stays and
  Openspot calls `show` again.

## Stdin

| Line                | Holds                                                         |
| ------------------- | ------------------------------------------------------------- |
| `input.<name>=`     | One input of the call, such as `item`, `value`, `text` or a field of the sheet. |
| `input.item.<key>=` | One key of its own of the pressed item, such as `port=:3000`. |
| `input.route=`      | The [route](06-items.md#pages) of the sheet that shows.       |
| `setting.<name>=`   | One [setting](07-actions-and-settings.md#settings), or its default. |

## The shell helper

`. "$OPENSPOT_SH"` loads functions that read stdin once and print values escaped. After it loads, read stdin only with
`value` or `openspot_input`, never `cat`.

| Function                                     | Does                                                                   |
| -------------------------------------------- | ---------------------------------------------------------------------- |
| `value <name>`                               | Prints each value of an input, or of a line such as `setting.city`.   |
| `openspot_input`                             | Prints stdin as it came.                                               |
| `openspot_item <id> <title> [detail] [icon]` | Prints a blank line, then one `item` block, so it starts a new block.  |
| `openspot_items [kind]`                      | Prints a block for each line of stdin: id, title, detail and icon, split by tabs. |
| `openspot_kv <key> <value>`                  | Prints one more line of the block above it.                            |
| `esc <text>`                                 | Prints a text as a value.                                              |
| `openspot_value <key> <text>`                | Prints each value of a key in a text, such as what a command printed.  |
| `openspot_rows <key>...`                     | Prints a line of tab-separated values for each block of stdin.         |
| `openspot_keep <file> [text]`                | Writes the text, or stdin, to the file at once, so a stop never leaves half of it. |
| `openspot_paste <text>`                      | Pastes the text into the front app, with `clipboard` in `uses`.        |
| `openspot_serve <function> "$@"`             | Runs the function at each call; see [A staying spot](12-modes.md#a-staying-spot). |

| Variable        | Is                                                            |
| --------------- | ------------------------------------------------------------- |
| `OPENSPOT_ID`   | The id of the spot.                                           |
| `OPENSPOT_DATA` | The folder where the spot keeps what lasts.                   |
| `OPENSPOT_SH`   | The path of the shell helper.                                 |
| `PATH`          | The `openspot` command, then the person's paths and the system's. |
| `LC_ALL`        | `en_US.UTF-8`.                                                |

## The life of a call

A call starts, prints frames and ends. It can stop at any time.

```text
start ──► frame ──► frame ──► end    exit 0: done; error= or another code: the message shows
  └──► stop: a newer value, a second press or a quit
```

- A `show` has 10 seconds to print its first frame. Other calls have no limit.
- A handler fails with `error=<message>` in its frame, or an exit code other than 0. The person sees the message, or
  the last line of stderr. `link=<url>` adds a page that helps fix it.
- A stop sends the terminate signal, then the kill signal, to the call's processes. A spot MUST NOT leave a file half
  written, so write with `openspot_keep`.
- A process that the script starts gets its stdin, unless the helper read it first, so close it, as in
  `curl "$url" </dev/null`.

## Write a message

A toast or a failure line tells the person what happened and what to do next.

- Instead of `Oops! Something went wrong.`, write `Openspot cannot find a screenshot.`
- Instead of `Error 1: osascript failed.`, write ``Copied, but Openspot cannot paste. Press `⌘V`, or allow Openspot in
  Accessibility.``

Say what still worked, and the step that fixes the rest, in one or two calm sentences. Put each key in backticks.
