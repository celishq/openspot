# Openspot protocol

`3.0` `draft`

This is the reference of the contract between a spot and Openspot: each file, key, call, block, class and command, in
the order a spot meets them. To build a spot one task at a time, start with the [guide](GUIDE.md).

## A spot

A spot is a folder `<name>.spot` in the spots folder, which Openspot runs.

```text
ports.spot/
  spot.toml
  ports.sh
  readme.md
  sample.sh
```

| File             | Required | Is                                                                                   |
| ---------------- | -------- | ------------------------------------------------------------------------------------ |
| `spot.toml`      | yes      | The [manifest](#the-manifest), which says what the spot has.                          |
| `<name>.<ext>`   | yes      | The script, named like the folder, such as `ports.sh`, `ports.js` or `ports.swift`.  |
| `readme.md`      | no       | The page that the Store shows about the spot.                                        |
| `sample.sh`      | no       | A script that prints what the spot shows, with made-up data.                         |
| `releases.jsonl` | no       | The signed releases of the spot, as [Signed releases](TRUST.md#signed-releases) says. |

- The id of a spot is the name of its folder, such as `ports`.
- Any other file of the folder, such as a script of shared code, is the spot's own.
- A spot folder must hold 25 MB or less, since it's shared as one unit.
- `readme.md`: a line that holds only a Markdown image of a file in the folder shows that PNG, JPEG, GIF, MOV or MP4.
- `readme.md`: an `https` picture is fetched once, with no cookies, and an `https` video shows as a link.
- `sample.sh`: publish ships what it prints as `sample.frame`, which the Store shows, and where a press runs nothing.
- Openspot moves a loose script of the spots folder into a spot folder of its name, with a `spot.toml` that holds the
  script's title.

## The manifest

The manifest is the file `spot.toml` of a spot folder: what the spot keeps, does, tells, binds and listens to.

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

| Key                | Type     | Default            | Is                                                                          |
| ------------------ | -------- | ------------------ | --------------------------------------------------------------------------- |
| `title`            | text     | the folder's name  | The name of the spot.                                                       |
| `icon`             | text     | none               | The icon of the spot, in a form that [`icon`](#keys-of-every-block) takes.  |
| `detail`           | text     | none               | The line under the title.                                                   |
| `keywords`         | [text]   | none               | More words that find the spot in the main search.                           |
| `uses`             | [text]   | none               | The features of the Mac that the spot uses, which [Uses](TRUST.md#uses) lists. |
| `views`            | [text]   | none               | The SwiftUI files of the spot, each a kind of block; see [Views](#views).    |
| `source`           | [text]   | none               | The Swift files or folders that a [Swift spot](#a-swift-spot) is built from. |
| `pages`            | [text]   | none               | The routes that the spot may show; see [Pages](#pages).                     |
| `stay`             | bool     | `false`            | Whether one process answers every call; see [A staying spot](#a-staying-spot). |
| `answers`          | text     | none               | Where the answers of `search` show: `last` or `card`.                       |
| `[settings]`       | table    | none               | One key for each [setting](#settings).                                      |
| `[actions.<id>]`   | table    | none               | One [action](#actionsid) of the spot.                                       |
| `[events.<name>]`  | table    | none               | One [event](#eventsname) that the spot tells the spots that bind it.        |
| `[bindings]`       | table    | none               | One key for each [spot that this spot binds](#bindings).                    |
| `[on]`             | table    | none               | The [triggers](#on) that call the spot by themselves.                       |

- A value is a string in quotes, a number, `true` or `false`, a list in brackets, or a table in braces.
- A wrong or unknown key, such as `titel`, keeps the spot from loading, and its fault names the key.
- `icon`: a path that doesn't start with `/` starts at the spot folder.
- `answers`: with none, the answers of `search` show first. `last` shows them under the other results, and `card` shows
  one card in their place, as [The main search](#the-main-search) says.
- A spot has a sheet, unless it has an action with a `title` and no key in `[on]`. Such a spot runs its one action on
  Return, or opens the keys of its actions.
- `openspot schema` prints the JSON Schema of `spot.toml`, and [`schema/spot.schema.json`](schema/spot.schema.json)
  holds a copy. An editor that reads a `#:schema` line at the top of the file, such as one with Taplo, checks each key.
- The keys that only Openspot's own spots take are in [The app's own words](spots/AGENTS.md#the-apps-own-words).

### [settings]

`[settings]` holds one key for each setting, a choice of the person that the spot keeps, such as a city or a token.

```toml
[settings]
city = { type = "text", title = "City", default = "Paris" }
units = { type = "choice", options = ["Celsius", "Fahrenheit"], default = "Celsius" }
token = { type = "secret", title = "Token" }
```

| Key           | Type      | Default               | Is                                                          |
| ------------- | --------- | --------------------- | ----------------------------------------------------------- |
| `type`        | text      | required              | The [type](#types) of the setting's value.                  |
| `title`       | text      | the key, capitalised  | The words of the setting's row in the spot's Settings.      |
| `icon`        | text      | none                  | The icon of the setting.                                    |
| `default`     | its type  | none                  | The value that a call gets while the person has set none.   |
| `description` | text      | none                  | What the setting is for.                                    |
| `options`     | [text]    | none                  | The values that a `choice` offers.                          |

- Each call gets each setting on stdin as `setting.<name>=`, or its default when it has no value. A JavaScript spot reads
  them in `env.settings`.
- Openspot shows and keeps a `choice` or a `bool` with no call. Return on another setting in the spot's Settings calls
  the handler of the setting's name, which can answer with a [form](#forms).
- `openspot setting set <key> [value]` keeps a value, or removes it.
- A `secret` never comes on stdin. The spot reads it with `openspot setting get <name>`.
- A `secret` is kept in the Keychain, asked for in Openspot's own form, and hidden in the call log, the stats, a toast
  and a failure line.
- A setting must never be named `icon`, `enabled`, `menubar`, `open`, `float` or `key.<action>`, which Openspot keeps
  for the person.

### [actions.<id>]

`[actions.<id>]` declares one action, a thing the spot can do, with typed inputs and outputs.

```toml
[actions.brew]
title = "Brew Tea"
inputs.minutes = { type = "number", default = 4, description = "How long the tea steeps" }
outputs.ready = "date"
```

| Key              | Type                     | Default | Is                                                             |
| ---------------- | ------------------------ | ------- | -------------------------------------------------------------- |
| `title`          | text                     | none    | The words that the person runs the action by.                  |
| `icon`           | text                     | none    | The icon of the action.                                        |
| `confirm`        | text                     | none    | The words that ask the person to press a second time.          |
| `inputs.<name>`  | a [type](#types) or a table | none | A value that the call takes, as the input `<name>`.          |
| `outputs.<name>` | a [type](#types) or a table | none | A value that the action gives back, as `out.<name>=`.        |

- An action with a `title` is one the person runs, from the main search, the ⌘K menu and a key that the spot's Settings
  give it. An action with no `title` runs only from a block, a view, a timer or another spot.
- A run of the action calls the handler `<id>`, with its inputs on stdin.
- `confirm`: the first press shows the words, and the second press runs the action. A key of the action asks the same
  way.
- An action must never be named `show`, `press` or `drag`, or like a handler that `[on]` calls. A spot that breaks this
  doesn't load.
- Before a call, Openspot checks each declared input and fills its default. A wrong type, or a required input that is
  empty, keeps the call from running.
- An input that the action doesn't declare, such as another field of the sheet, passes unchecked.
- The action gives its values as `out.<name>=` lines in its frame's [root](#the-root), or answers with a view instead.
  Openspot checks the values against `outputs` only on a frame that holds an `out.` line.
- An action whose required input is empty and has no default asks for it with a drawn [form](#forms).
- `openspot spot actions [id]` prints each action, and each command of the spot's uses, typed as JSON Schema.

### [events.<name>]

`[events.<name>]` declares one event that the spot tells the spots that bind it, with a type for each of its values.

```toml
[events.finished]
minutes = { type = "number", required = true }
```

- `<name>` must hold no dot.
- Each value takes a [type](#types), or the table of an [input](#an-input).
- `openspot emit <name> [<name>=<value>...]` sends the event; see [openspot emit](#openspot-emit).

### [bindings]

`[bindings]` names each spot that this spot runs or listens to, under a name of its choice.

```toml
[bindings]
picker = { spot = "openspot/snooze" }
```

| Key      | Type | Default  | Is                                    |
| -------- | ---- | -------- | ------------------------------------- |
| `<name>` | table | none    | One spot that this spot binds.        |
| `spot`   | text | required | The id of the bound spot.             |

- A binding's name must hold no dot.
- The person approves each binding when the spot is added, and the spot's page lists it beside its uses.
- A bound spot that isn't installed shows as missing.
- `openspot run <name>.<action>` runs an action of the bound spot; see [openspot run](#openspot-run).
- `"<name>.<event>" = true` in `[on]` listens to an event of the bound spot.

### [on]

`[on]` holds the triggers of a spot: each thing that calls the spot by itself, with its filter.

```toml
[on]
"panel.open" = true
"power.change" = "^(ac|battery)$"
every = 300
command = ["note"]
```

| Key                   | Type            | Calls               | Is                                                         |
| --------------------- | --------------- | ------------------- | ---------------------------------------------------------- |
| `"<event>"`           | `true` or regex | `show` or `<event>` | An [event](#events) that the spot listens to.              |
| `"<binding>.<event>"` | `true`          | `<binding>.<event>` | An event of a spot that it [binds](#bindings).             |
| `every`               | number          | `every`             | The seconds between calls while one of the spot's places shows. |
| `schedule`            | [text]          | `schedule`          | Cron lines of the times to call the spot, shown or not.    |
| `command`             | [text]          | `command`           | The words of the spot's slash commands.                    |
| `search`              | `true` or regex | `show` or `search`  | The texts of the main search that the spot answers.        |
| `drop`                | [text]          | `drop`              | The kinds of file that the spot's card takes.              |

- `true` takes each event, and a string is a regular expression that the event's value must match.
- An event with no value, such as `clipboard.change`, takes only `true`.
- `panel.open`, `sheet.open` and `spot.want` call `show`. Each other event calls the handler of its own name, with its
  value as the input `value`.
- At load, Openspot checks each key. An unknown event, a filter on an event with no value, or a `<binding>.<event>`
  whose binding isn't in `[bindings]` keeps the spot from loading, and its fault names the key.
- `"<binding>.<event>"`: the bound spot must declare the event in its `[events]`, which Openspot checks when that spot
  loads too.
- `"<binding>.<event>"`: each value of the event comes as `input.<name>=`, and the call counts as one the person didn't
  press.
- `every`: it's a whole number of seconds. Openspot also calls `every` when the Mac wakes, and its frame draws as a
  show's does.
- `schedule`: a line is minute, hour, day, month and weekday, such as `"0 9 * * 1-5"` for 9:00 on each weekday.
- `schedule`: the call gets the line as `cron`, and the seconds it came late as `late`. A time missed while the Mac
  slept runs once at wake.
- `schedule`: a spot of the person's spots folder with a `schedule` starts off, until the person turns it on.
- `command`: a word must start with a letter, and hold only letters, digits, `-` and `_`. Each word is a row `/<word>`
  of the main search; see [Slash commands](#slash-commands).
- `search`: `true` adds the items of the spot's `show` to the main search. A string calls `search` at each text that
  matches; see [The main search](#the-main-search).
- `drop`: each entry is an extension such as `png`, `folder`, or `*`. A drop on the card calls `drop` with a `file`
  input for each path, after the card's running call ends.

### Events

Each event that Openspot raises, which a key of [`[on]`](#on) names. Its handler gets the value as the input `value`.

| Event              | Value                            | Raised                                                      |
| ------------------ | -------------------------------- | ----------------------------------------------------------- |
| `sheet.open`       | none                             | When the spot's sheet opens.                                |
| `panel.open`       | none                             | Each time the panel opens, and once when Openspot starts.   |
| `sheet.text`       | the text                         | At each change of the sheet's search text, and when the sheet opens. |
| `spot.want`        | none                             | When a place first shows the spot in an open of the panel.  |
| `clipboard.change` | none                             | When the clipboard changes.                                 |
| `app.front`        | its bundle ID                    | When another app comes to the front.                        |
| `app.update`       | its version                      | When Openspot has downloaded an update.                     |
| `app.launch`       | none                             | Once when Openspot starts.                                  |
| `screen.wake`      | none                             | When the screen wakes.                                      |
| `system.load`      | `cpu=<percent> memory=<percent>` | Every 5 seconds while a place of the spot shows.            |
| `power.change`     | `ac`, `battery` or `ups`         | When the power source changes, or the battery gains or loses a percent. |
| `disk.mount`       | its path                         | When a disk or a volume mounts.                             |
| `device.connect`   | its name                         | When a USB device connects.                                 |

- Openspot calls a spot only while one of its places shows, except at `app.launch` and `app.update`.
- A spot has one read at a time.
- `sheet.open`: the sheet calls `show` at each open, unless it called it less than 5 seconds ago. With
  `"sheet.open" = true`, it calls `show` even then, and a spot of titled actions gets a sheet.
- `sheet.text`: the call also gets each text the person may have meant, such as in another keyboard layout, as `alt`.
  The spot prints the items that match.
- `spot.want`: `show` comes when a place starts to show a spot whose events haven't come yet, such as its card on the
  grid or its rows in the main search.
- `device.connect`: a Bluetooth device raises no event.

## Types

A type says what form a value takes. Each input, output, setting and value of an event has one.

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
| `[<type>]` | A list of values of that type, such as `[file]`, one line for each value.   |

### An input

An input, an output, a setting and a value of an event take a type alone, such as `url = "url"`, or a table.

| Key           | Type     | Default  | Is                                                      |
| ------------- | -------- | -------- | ------------------------------------------------------- |
| `type`        | text     | required | The [type](#types) of the value.                        |
| `required`    | bool     | `false`  | Whether the value must not be empty.                    |
| `default`     | its type | none     | The value that a call gets when it's given none.        |
| `description` | text     | none     | What the value is, which a drawn form shows as a placeholder. |
| `options`     | [text]   | none     | The values that a `choice` offers.                      |

- A type alone is a value that may be empty.
- A list type takes no `default`.

## The calls

A call is one run of the spot's code: Openspot gives it the name of a handler as its first argument and a message on
stdin, and reads frames from its stdout. A handler is the part of the spot's code that answers one kind of call.

```text
ports.sh press
```

```ini
input.item=4120
setting.signal=TERM
```

Openspot runs `ports.sh` with the argument `press`, and the message above on its stdin.

| Call                       | Comes                                                                      | Inputs                                   |
| -------------------------- | -------------------------------------------------------------------------- | ---------------------------------------- |
| `<spot> show`              | When its sheet opens, a place needs its view, or `show` comes from `[on]`. | `event`, `route`                         |
| `<spot> <action>`          | When the [action](#actionsid) runs, or a block with the action's id is pressed or changed. | the action's inputs, and `item` or `value` |
| `<spot> press`             | When the person presses an item, or the card of a spot with no sheet.      | `item`, and `item.<key>`                 |
| `<spot> command`           | When the person runs one of its slash commands.                            | `name`, `text`                           |
| `<spot> search`            | When a text of the main search matches `search` of its `[on]`.             | `text`, `alt`                            |
| `<spot> every`             | Every `every` seconds of its `[on]` while one of its places shows.         | none                                     |
| `<spot> schedule`          | At each time of `schedule` in its `[on]`, shown or not.                    | `cron`, `late`                           |
| `<spot> drop`              | When the person drops files on its card.                                   | `file`, once for each path               |
| `<spot> drag`              | When the person drags items that stand for files out of its sheet.         | `item`, once for each item               |
| `<spot> <event>`           | When another [event](#events) of its `[on]` comes, such as `system.load`.  | `value`                                  |
| `<spot> <binding>.<event>` | When a spot that it binds sends the event.                                 | the values of the event                  |

- `<spot> <action>`: a timer, a view's `spot.send` and `openspot run` of a spot that binds it call it too.
- `show`, `search`, `every` and an event's handler are reads. A read must never change anything or open anything; see
  [The openspot command](#the-openspot-command).
- `show` gets the moment that asked for it as `event`, such as `panel.open` or `sheet.open`.
- A call that answers with no view closes the panel, unless the pressed block or item has `close=false`.
- A process that the spot starts inherits its stdin, unless the spot reads it first or closes it for that process, as
  in `curl "$url" </dev/null`.

| Variable        | Is                                                                                          |
| --------------- | ------------------------------------------------------------------------------------------- |
| `OPENSPOT_ID`   | The id of the spot.                                                                          |
| `OPENSPOT_DATA` | The data folder of the spot, where it keeps what lasts.                                     |
| `OPENSPOT_SH`   | The path of the shell helper.                                                                |
| `PATH`          | The `openspot` command first, then the person's paths and the folders of the system.        |
| `LC_ALL`        | `en_US.UTF-8`, so that each tool reads text as UTF-8.                                        |

- `PATH`: after the person's paths come `/opt/homebrew/bin`, `/usr/local/bin`, `/usr/bin`, `/bin`, `/usr/sbin` and
  `/sbin`.
- `LC_ALL`: a command that handles raw bytes sets `LC_ALL=C` for itself.

The shell helper is a file of functions that a shell spot loads with `. "$OPENSPOT_SH"`. It reads stdin once, keeps it,
and writes values for you.

| Function                                     | Does                                                                                            |
| -------------------------------------------- | ----------------------------------------------------------------------------------------------- |
| `value <name>`                               | Prints each value of the input `<name>`, or of the key `<name>` such as `setting.city`, one a line. |
| `esc <text>`                                 | Prints text as a value.                                                                         |
| `openspot_value <key> <text>`                | Prints each value of the key from a text, such as what an `openspot` command printed.           |
| `openspot_input`                             | Prints the stdin of the call as it came.                                                        |
| `openspot_kv <key> <value>`                  | Prints one line, with its value escaped.                                                        |
| `openspot_item <id> <title> [detail] [icon]` | Prints one `item` block.                                                                        |
| `openspot_items [kind]`                      | Prints a block for each tab-separated line of stdin: id, title, detail and icon.                |
| `openspot_rows <key>...`                     | Prints a tab-separated line for each block of stdin, with the value of each key.                |
| `openspot_serve <function> "$@"`             | Runs the function with the arguments of each call, in each [mode](#modes).                      |
| `openspot_keep <file> [text]`                | Keeps the text, or stdin, in the file as a whole, or fails and keeps the old file.              |
| `openspot_paste <text>`                      | Pastes the text into the front app, and puts the clipboard back.                                |

- After the helper loads, a spot must read stdin with `value` or `openspot_input`, never `cat`. The function of
  `openspot_serve` gets an empty stdin.
- `openspot_paste` needs `clipboard` in `uses`.

## The message

The message is the text that a call finds on its stdin, in [the format](#the-format).

```ini
input.item=4120
input.item.port=:3000
setting.signal=TERM
```

| Key                 | Holds                                                                      |
| ------------------- | -------------------------------------------------------------------------- |
| `input.<name>=`     | One input of the call, such as an input of an action, `item`, `value` or `text`. |
| `input.item.<key>=` | One key of the item that a press or an action is on.                       |
| `input.route=`      | The [route](#pages) of the sheet that shows.                               |
| `setting.<name>=`   | One [setting](#settings), or its default.                                  |

- Each field of the sheet or of a form comes as `input.<id>=`.
- `input.item.<key>=` comes for each key of its own that the item holds, such as `port=:3000`.
- `input.route=`: the first sheet of a spot has none.
- `setting.<name>=`: a `secret` never comes.

## The format

The format is lines of `key=value`, which the message, each frame and each report of `openspot` use.

```ini
item=wifi
title=Wi-Fi
detail=Home · 82 Mb/s
---
```

- A line splits at its first `=`.
- A blank line ends a block, and a line `---` ends a frame.
- In a value, `\n` is a new line and `\\` is a backslash.
- An empty value is no value, and Openspot never splits a value.
- In a frame, Openspot skips a line with an unknown key and a block of an unknown kind, and `openspot check spots`
  reports each one.

## Modes

A mode is the way Openspot runs a spot's program.

| Mode                                  | Chosen by                                      | Is                                                     |
| ------------------------------------- | ---------------------------------------------- | ------------------------------------------------------ |
| A script                              | an executable script                           | A process for each call.                               |
| [A staying spot](#a-staying-spot)     | `stay = true` in the manifest                  | One process that answers each call.                    |
| [A JavaScript spot](#a-javascript-spot) | a `.js` file with no execute permission      | Code that runs inside Openspot.                        |
| [A Swift spot](#a-swift-spot)         | a Swift file with `#!/usr/bin/env swift`       | A program that Openspot builds once and runs at each call. |

### A staying spot

A staying spot is one process that gets each call on its stdin and answers on its stdout, while one of its places shows.

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

- `openspot_serve` runs `main` with the arguments of each call, so the same `main` works in every mode.
- With `"app.launch" = true` in `[on]`, the process runs from launch to quit.
- A second press of a running call stops it. The call ends 2 seconds later, unless the spot prints a frame for it
  first, and then it runs on to its end.
- A form, and a call that a newer value or search text stopped, stop at once.
- A show after the first is stopped after 10 seconds, and after 2 such slow shows Openspot ends the spot.
- A shell spot that waits in `openspot run` takes no other call until the run ends. Openspot sends it no read meanwhile,
  and the main search keeps its last answer.
- When no place shows the spot and no call waits, Openspot closes its stdin. The spot must end with each process it
  started, or its group gets the terminate signal 2 seconds later, and the kill signal 2 seconds after that.
- After 3 failures in one minute, Openspot starts the spot again only when its file changes.

> **Note:** A program that doesn't use `openspot_serve` reads and writes the calls itself. Openspot writes each call to
> stdin as one block: `call=<n>`, an `arg` line with the handler's name, then the message. The program prints
> `call=<n>` before the output of each call and `end=<n>` after it, and a frame of only `call=<n>` starts the output of
> that call. A stop of a call comes as `stop=<n>`.

### A JavaScript spot

A JavaScript spot is a `.js` file that runs inside Openspot, so it answers in the same keystroke, and its handlers can
wait for the person or another spot.

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

| Name                          | Is                                                                                  |
| ----------------------------- | ----------------------------------------------------------------------------------- |
| `export default`              | The object of handlers, each a function of `(input, env)` named for its call.       |
| `input`                       | The values of the call, typed by their declaration.                                 |
| `env.<noun>.<verb>(...)`      | A command that the spot may call, such as `env.timer.add(...)`.                     |
| `env.<binding>.<action>(inputs)` | A run of an action of a bound spot, which resolves to its values.                |
| `env.emit(event, values)`     | A send of one of the spot's [events](#eventsname).                                  |
| `env.settings`                | The settings of the spot.                                                           |
| `env.open(id)`                | An open of a spot.                                                                  |
| `openspot.frame(objects)`     | The text of a frame, with an object for each block.                                 |
| `openspot.call(words, stdin)` | A run of any other `openspot` command, which returns `{ stdout, code }`.            |

- A spot is one file: any other `import` or `export` keeps it from loading.
- `input`: a `number` or a `duration` is a number, a `bool` a boolean, a list an array, and any other value a string.
  The keys of an item are `input["item.<key>"]`.
- `env.<noun>.<verb>`: the noun and the verb are in camelCase, such as `env.screen.recordStop()`, and a noun with no
  verb is the noun itself, such as `env.toast("Copied")`.
- `env.<noun>.<verb>`: its arguments are the words of the command in order, an object for inputs as `<name>=<value>`,
  then one object of options, such as `{ dryRun: true }`. It resolves to what the command prints, and rejects with its
  failure line.
- `env.<binding>.<action>`: it resolves to `null` when the person closes the view of the bound spot.
- A handler returns a string, the text of a frame; an array of objects, which `openspot.frame` writes as blocks; an
  object, whose keys become `out.<name>` lines; or nothing. A throw fails the call with its message.
- `openspot.frame`: an object whose first key is `frame` is the root.
- The spot has no files, no network and no process.
- Openspot waits 2 ms for the frame of a key, and shows a later one at the next keystroke.
- A call has 10 seconds of the time its code runs. An `await` counts nothing, and the spot takes other calls while one
  waits. A loop that never awaits is stopped.
- A handler that awaits a promise that nothing can settle, with no `env` call under way, fails once its spot has had no
  call for 30 seconds.
- `openspot types` writes `openspot.d.ts` beside the file. With `/** @satisfies {import("./openspot").Handlers} */`
  before `export default`, an editor checks each handler, input, output, event, binding and command.

### A Swift spot

A Swift spot is a program that Openspot builds once from the spot's Swift files, and runs at each call.

- A Swift file with `#!/usr/bin/env swift` on its first line is the spot's script.
- `source`: each item names one more Swift file, or a folder of them, as a plain path in the spot folder, with no `.`,
  no `..`, and no `/` at its start or end.
- The program gets the handler's name in `CommandLine.arguments[1]`, and the message on stdin, as a script does.
- Openspot needs the Command Line Tools to build it, and builds again when a file changes.
- A spot with no `source` runs as a script until its build is done. A failed build is the failure of each call until a
  file changes.
- The program must start each `openspot` command with `posix_spawn`, since Foundation's `Process` closes descriptor 11;
  see [Uses](TRUST.md#uses).
- `openspot types` writes `Openspot.swift` beside the spot, for the spot to list in `source`. It holds a `Handlers`
  protocol with a method for each handler, typed inputs and outputs, an `Env` of its commands, bindings, `emit` and
  `open`, and `Openspot.serve`.
- `Openspot.serve` reads the call, runs its handler and prints its answer, or `error=` for a throw.
- A shared spot carries the program as `<name>.<hash>.program`, by the SHA-256 of its Swift files. A Mac with no tools
  runs it while the hash matches; see [The review before an add](TRUST.md#the-review-before-an-add).

## The life of a call

A call starts, prints frames and ends, and it can stop at any time.

```text
start ──► frame ──► frame ──► ... ──► end    exit 0: done; error= or another code: the message shows
  └──► stop: a newer value, a second press or a quit; terminate signal, then kill
```

- A `show` has 10 seconds to print its first frame or end. Other calls have no limit.
- A wait inside an `openspot` command for the person or another spot doesn't count against a limit.
- A frame must hold 32 MB or less, and past it the call shows nothing more.
- A new value of a block stops the older call of that block, and a second press stops a running call. Its process group
  gets the terminate signal, then the kill signal, and a stopped call changes nothing.
- A spot's keys run one at a time, in order, and never stop a call. At most 8 presses wait, and a later one is dropped.
- A staying spot gets each press at once, while fewer than 8 calls of its keys are open.
- A handler fails with `error=<message>` in its frame's root, a throw in JavaScript, or an exit code other than 0. The
  person sees the message, or the last line of stderr.
- A failure can print `link=<url>`, a web page that helps fix it.
- A failed show at `panel.open` only marks its card.
- A run of a failed handler from another spot exits 1 with the message.
- A stop can come at any time, and two calls can run at once, so a spot must never leave a file half written.

## Frames

A frame is everything that a call shows at one time: the blocks it prints up to a line `---` or its end.

```ini
frame=
title=Ports
detail=4 listening

item=4120
title=:3000
detail=node
---
```

- Openspot draws each frame as soon as it arrives.
- The first frame of a call replaces what shows, and so does a later frame with a `frame=` line.
- A later frame with no `frame=` line changes only the blocks it prints.
- If a show prints nothing, the spot shows nothing. If another call prints nothing, Openspot calls `show` again.
- Openspot ignores what an out-of-date call prints.
- A value that comes from data must be printed with `openspot_kv`, `openspot_item`, `esc` or `openspot.frame`, so that
  it can't add a line or a block.
- Openspot removes escape codes, such as colours and terminal progress, from the output.
- A block with the id of a block that shows changes that block. A block of the same kind changes only the keys it
  prints, and the other keys and its place stay.
- A block of another kind with that id replaces the block with only the keys it prints, and keeps its place and the
  blocks inside it.
- A new `parent=<id>` moves the block into that block, and `parent=` with no value moves it to the root.
- A block with a new id joins the end of its parent.
- A later block in the same frame changes an earlier one by the same rules.

### The root

The root is the block of a frame that holds the frame's own keys. It starts with `frame=`, with `error=` or with a value
of the call, and isn't drawn.

| Key        | Type             | Is                                                                     |
| ---------- | ---------------- | ---------------------------------------------------------------------- |
| `frame`    | text             | The route of the sheet that the frame is for, which may be empty.      |
| `class`    | classes          | The [layout](#layouts) of the frame's blocks, as on a box.             |
| `title`    | text             | The title of the card.                                                 |
| `detail`   | text             | The line under the card's title.                                       |
| `active`   | bool             | Whether the spot's thing is on.                                        |
| `recents`  | bool             | Whether the items that were pressed most recently come first.          |
| `value`    | id               | The block that is the spot's value on a card and in the menu bar.      |
| `type`     | form             | The kind of frame, which makes it a [form](#forms).                    |
| `progress` | number, 0 to 1   | How much of the call's work is done.                                   |
| `error`    | text             | The message of a failure of the call.                                  |
| `call`     | number           | The call of a staying spot that the output that follows is for.        |
| `end`      | number           | The end of the output of a call of a staying spot.                     |

- The root can come anywhere in the frame. Openspot skips and reports a second root, and a frame with only a root
  changes no block.
- `out.<name>=<value>` gives a value of an action's `outputs`, once for each value; see [`[actions.<id>]`](#actionsid).
- `title` and `detail`: with `progress`, they show only on the running call.
- `active=true` shows on the card that the spot's thing is on.
- `recents=false` keeps the items in the order the spot prints them.
- `value=<id>` names the spot's value on [the card](#the-card), in [the menu bar](#the-menu-bar) and in
  [the main search](#the-main-search).
- `call=<n>` and `end=<n>` can sit in a block of their own; see [A staying spot](#a-staying-spot).

## Blocks

A block is one thing that a frame shows: lines that start with its kind and its id, such as `item=home`, and end at a
blank line.

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

| Kind      | Is                                                                   |
| --------- | -------------------------------------------------------------------- |
| `box`     | A [box](#box) that lays out the blocks inside it.                    |
| `text`    | [Words](#text).                                                      |
| `icon`    | An [icon](#icon) alone.                                              |
| `picture` | An [image](#picture) that fills its area.                            |
| `number`  | One [value](#number), as text, a ring or a bar.                      |
| `series`  | [Points](#series) over time, as a bar for each.                      |
| `button`  | A [button](#button), or a row of the ⌘K menu.                        |
| `field`   | A [text field](#field), or another input with a `type`.              |
| `switch`  | A [switch](#switch).                                                 |
| `choice`  | A [menu](#choice) of the `option` blocks after it.                   |
| `option`  | One [option](#option) of the `choice` right before it.               |
| `items`   | The [list](#items) that the person searches and presses.             |
| `item`    | A [row](#items) of the list.                                         |
| A view    | What a SwiftUI file of the spot draws; see [Views](#views).          |

- The first key of a block is its kind, and its value is the block's id.
- The id names the block in the layout, the action that it runs, and what moves when it changes.
- A frame with no [layout](#layouts) gets the one Openspot makes: a list that the person searches. There each block is
  an item, a `button` is a row of the ⌘K menu, and a `choice` shows over the list.

### Keys of every block

| Key      | Type     | Default | Is                                                                 |
| -------- | -------- | ------- | ------------------------------------------------------------------ |
| `parent` | id       | none    | The block that this block sits inside.                             |
| `class`  | classes  | none    | The [classes](#classes) that place and style the block.            |
| `grow`   | bool     | none    | Whether the block takes the free height of its box.                |
| `title`  | text     | none    | The first line of the block's words.                               |
| `detail` | text     | none    | The line under the title.                                          |
| `icon`   | text     | none    | The icon before the title.                                         |
| `tone`   | text     | none    | The colour of the block's words: `good`, `warn` or `bad`.          |

- `parent`: with none, the block sits in the root.
- `grow=false` keeps an `items` block, a `multiline` field or a view to its own height, which they leave by themselves.
- `icon`: an image file of the spot folder, such as `cups.png`; an `https://` image, downloaded once; the Finder icon of
  a path with a `/` or a leading `~`; an SF Symbol, such as `wifi`; or any other text, such as `😀`.
- `icon` draws the same on every kind and in every place.
- `tone` colours the detail, or the title when there is no detail.

### box

A `box` holds the blocks whose `parent` names it, and lays them out by its classes.

- A box lays out its blocks in a column, or in a row with `flex-row`, a grid with `grid grid-cols-<n>`, or layers with
  `relative`.
- It draws nothing of its own but what its classes give, such as a fill.
- Inside an `items` block, a box is a group: its `title` heads the items inside it.

### text

A `text` shows words: its `title` and its `detail`.

| Key     | Type | Default | Is                                                    |
| ------- | ---- | ------- | ----------------------------------------------------- |
| `value` | text | none    | The words of a text that is a value on a card.        |
| `color` | `#RRGGBB` | none | The colour of a bar at the text's edge.            |

- A `text` inside an `items` block is a fault that `openspot check spots` reports, and the block still shows.

### icon

An `icon` shows one icon alone.

| Key     | Type | Default | Is                                                       |
| ------- | ---- | ------- | -------------------------------------------------------- |
| `value` | text | none    | The icon, in a form that [`icon`](#keys-of-every-block) takes. |

### picture

A `picture` shows an image that fills its area.

| Key    | Type | Default | Is                                                        |
| ------ | ---- | ------- | --------------------------------------------------------- |
| `icon` | text | none    | The image, in a form that [`icon`](#keys-of-every-block) takes. |

### number

A `number` shows one value, such as the battery, as text, a ring or a bar.

```ini
number=battery
title=Battery
value=84
max=100
unit=%
type=ring
```

| Key       | Type      | Default | Is                                                  |
| --------- | --------- | ------- | --------------------------------------------------- |
| `value`   | number    | none    | The number.                                         |
| `max`     | number    | none    | The value of a full ring or bar.                    |
| `unit`    | text      | none    | The words after the value, as in `84%`.             |
| `display` | text      | none    | The words that show in place of the value.          |
| `type`    | text      | text    | The look: `ring` or `bar`.                          |
| `color`   | `#RRGGBB` | none    | The colour of a bar at the number's edge.           |

- A ring or a bar with no `max` is a fault that `openspot check spots` reports.
- Inside an `items` block, a number shows its value on the right of its title, or a ring with `type=ring`.

### series

A `series` shows points over time, such as the use of the CPU, as its last value over a bar for each point.

```ini
series=cpu
title=CPU
value=12,30,18,-,25,40,22
max=100
unit=%
```

| Key       | Type     | Default            | Is                                                     |
| --------- | -------- | ------------------ | ------------------------------------------------------ |
| `value`   | numbers  | none               | The points, oldest first, split by commas.             |
| `add`     | numbers  | none               | Points to put after the last, split by commas.         |
| `keep`    | number   | `60`               | The most points that the series holds.                 |
| `max`     | number   | the largest point  | The value of a full bar.                               |
| `unit`    | text     | none               | The words after the value, as on a number.             |
| `display` | text     | none               | The words that show in place of the value.             |

- `value`: `-` is a point with no value, drawn as a gap. A later `value` replaces all the points.
- `add`: a block with both `value` and `add` replaces the points, then adds.
- `keep`: it must be 600 or less. When an add passes it, the oldest points drop.
- Inside an `items` block, a series shows the bars of its points.

### button

A `button` is a verb that the person presses, such as Forget, and a press calls the handler of its id.

```ini
button=rename
title=Rename
scope=spot
shortcut=cmd+r
```

| Key        | Type | Default | Is                                                                  |
| ---------- | ---- | ------- | ------------------------------------------------------------------- |
| `scope`    | text | `item`  | Where the button shows in the ⌘K menu: `item` or `spot`.            |
| `shortcut` | text | none    | The key that presses the button.                                    |
| `confirm`  | text | none    | The words that ask the person to press a second time.               |
| `close`    | bool | none    | Whether the panel closes after a press that answers with no view.   |

- A button is a row of the ⌘K menu when it has a `scope`, sits inside the `items` block, or is in a frame with no
  layout. Any other button draws where the layout places it.
- A press calls `<spot> <id>`, which needs no `[actions.<id>]`. Declare one to type its inputs.
- A button of the ⌘K menu passes the selected item as the input `item`, with its own keys as `item.<key>`.
- `scope=item` shows the button only while an item is selected, and `scope=spot` always. A button of the ⌘K menu needs
  a `title`.
- `button=press` gives Return its `title` in the ⌘K menu and the footer.
- `shortcut` is a letter, a digit, `return`, `backspace` or `,`, after `cmd+`, `shift+`, both or neither, or `escape`
  alone, which presses the button in place of closing the sheet.
- `shortcut`: in a ⌘K menu of 3 rows or more, only a `shortcut` with `cmd` works, since a field searches the rows.
- The blocks inside a button are its look, and take its `hover:`, `pressed:`, `selected:` and `focus:`.

### field

A `field` is a text field, or another input that its `type` names.

| Key           | Type   | Default | Is                                                       |
| ------------- | ------ | ------- | -------------------------------------------------------- |
| `value`       | text   | none    | The text of the field.                                   |
| `type`        | text   | none    | The kind of input: `multiline`, `slider`, `search` or `hotkey`. |
| `placeholder` | text   | none    | The words that show while the field is empty.            |
| `required`    | bool   | none    | Whether a form needs a value in the field.               |
| `readonly`    | bool   | none    | Whether the person can't change the field.               |
| `min`         | number | `0`     | The lowest value of a slider.                            |
| `max`         | number | `100`   | The highest value of a slider.                           |
| `recording`   | bool   | none    | Whether a `hotkey` field records a key now.              |
| `shake`       | bool   | none    | Whether a shake or a tap of one modifier can be the key of a `hotkey` field. |

- A change calls `<spot> <id>` with the field's value as `value`. A text field sends as you type, and a slider as you
  drag.
- `type`: none is one line, `multiline` several lines that take the free height, `slider` a whole number from `min` to
  `max`, and `search` the search field of the [items](#items).
- `hotkey` shows keycaps, and records a key at Return or a click on it. Every key then goes to it, Esc brings back its
  key, and the recorded key runs its handler with the key as `value`.
- While a sheet with a `hotkey` field shows, Openspot's own keys are off.
- A text field or a slider never closes the panel. A `hotkey` field closes it after it sends only with `close=true`.

### switch

A `switch` is a switch that the person turns on or off.

| Key     | Type | Default | Is                                               |
| ------- | ---- | ------- | ------------------------------------------------ |
| `value` | bool | `false` | Whether the switch is on.                        |
| `type`  | text | none    | The look: `tick`, a round tick before its words. |

- A press calls `<spot> <id>` with `value=true` or `value=false`.
- A switch closes the panel after it sends only with `close=true`.

### choice

A `choice` is a menu of the `option` blocks that follow it.

| Key     | Type      | Default | Is                                                          |
| ------- | --------- | ------- | ----------------------------------------------------------- |
| `value` | id        | none    | The chosen option.                                          |
| `type`  | text      | none    | The look: `list`, `swatches` or `multiple`.                 |
| `color` | `#RRGGBB` | none    | One colour of a `swatches` choice, one line for each.       |

- A pick calls `<spot> <id>` with the option's id, or the colour of a swatch, as `value`.
- `type`: none is a menu, `list` a list of its options, `swatches` a swatch of each `color`, and `multiple`, in a form,
  several options with a `value` line for each one chosen.
- A `choice` printed again with options takes the new options, and one printed with none keeps its options.
- A choice closes the panel after it sends only with `close=true`.

### option

An `option` is one option of the `choice` right before it.

| Key     | Type | Default | Is                     |
| ------- | ---- | ------- | ---------------------- |
| `title` | text | the id  | The words of the option. |
| `icon`  | text | none    | The icon of the option.  |

### Items

The `items` block is the list that the person searches and presses, and each block inside it is an item. An `item` block
is a row of words in it.

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

button=forget
parent=devices
title=Forget
```

| Key             | Type   | Default | Is                                                                   |
| --------------- | ------ | ------- | -------------------------------------------------------------------- |
| `title`         | text   | the id  | The first line of the row.                                           |
| `detail`        | text   | none    | The line under the title.                                            |
| `icon`          | text   | none    | The icon of the row.                                                 |
| `tone`          | text   | none    | A dot of its colour on the icon.                                     |
| `value`         | bool   | none    | Whether the row shows a checkmark.                                   |
| `place`         | text   | none    | Where the item sits in its spot, which the main search shows.        |
| `keywords`      | text   | none    | Words that find the item but don't show, split by commas.            |
| `pin`           | text   | none    | The edge that the item stays at while the rest scroll: `top` or `bottom`. |
| `hides`         | id     | none    | A button of the ⌘K menu that the item doesn't offer.                 |
| `file`          | path   | none    | The file that the item stands for.                                   |
| `close`         | bool   | none    | Whether the panel closes after a press of the item.                  |
| `shake`         | bool   | none    | Whether a shake can be the key that the item records.                |
| `open.title`    | text   | none    | The words of Return on this item, in place of the `title` of `button=press`. |
| `route`         | text   | none    | The [route](#pages) that a press opens at once.                      |
| `route.title`   | text   | the title | The title of the route's sheet.                                    |
| `route.replace` | bool   | none    | Whether the route's sheet replaces the one that shows.               |

- A press of an item calls `press` with its id as the input `item`, a press of a switch runs its handler with
  `value=true` or `false`, and a press of a `hotkey` field records a key.
- An item can hold keys of its own, such as `meeting=42`, which come back as the input `item.meeting`.
- A frame must have one `items` block at most. Its classes lay out each item, such as `grid grid-cols-4` for a grid of
  tiles, where each item shows its icon with its title and detail under it.
- A `button` inside the `items` block is a row of the [⌘K menu](#button).
- An item is one block, so a block inside an item doesn't show, and `openspot check spots` reports it.
- An `item` outside a list is a fault that `openspot check spots` reports, and the block still shows.
- `place`: the main search shows `<spot> › <place>`.
- `hides`: one line for each button.
- `file`: the path must start with `/`. A drag carries only the files that still exist, and a drag that ends in another
  app calls `drag` with an `item` input for each item.
- `close=false` keeps the panel open after a press of the item, or a key it records.
- `route`: a press opens the route with no call of `press`.
- `route.replace=true`: going back skips the replaced sheet.
- `class=sr-only` on an item of a grid shows only its icon.
- In a frame with a layout, only a `field` with `type=search` adds a search field, where the layout puts it. Openspot
  searches the items, and puts the items pressed most recently first.

## Layouts

A layout places the blocks of a frame: `parent` puts a block inside another, and `class` says how each box lays out what
it holds.

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
```

- A frame has a layout when its root has a `class`, or when it holds an `items` block. Each block then draws where the
  layout puts it, and only the blocks inside the `items` block are items.
- A `box`, a `parent` or a class on another block doesn't make a layout. In a frame with no layout,
  `openspot check spots` reports each `box` and `parent`, and a class styles its block only where the frame draws a
  tree, such as on a card.
- Blocks that share a parent keep the order of their lines.
- In a grid, `col-span-<n>` and `row-span-<n>` make a block cover more cells. In layers, `absolute` with `inset-0`, or
  with an edge such as `top-0`, pins a block to its box.
- A divider is a box with `class=h-px bg-tile`.
- The arrows move the keys through each switch, field, choice and button in the order of the tree, above the items and
  under them.
- `grow` takes the free space of a row or a column, and blocks that grow in one row get equal widths.
- A `parent` that names no block, and an unknown class, are faults that `openspot check spots` reports. The block then
  sits in the root, and the class is skipped.
- The check also reports more than one button with `bg-accent`, a title that may not fit its place, and a `text` that
  its classes make shorter than its words.

## Classes

A class styles a block, with the name that Tailwind CSS gives it. Every size and colour comes from the theme.

```ini
box=row
class=flex-row items-center gap-2 p-3 bg-tile rounded-inner

text=name
parent=row
title=Home Network of the Whole Family
class=grow font-semibold text-accent truncate
```

| Class                                                          | Is                                                          |
| -------------------------------------------------------------- | ----------------------------------------------------------- |
| `flex-col`                                                     | A column, the layout of a box with no class.                |
| `flex-row`                                                     | A row.                                                      |
| `grid`, `grid-cols-<n>`                                        | A grid of `<n>` columns.                                    |
| `col-span-<n>`, `row-span-<n>`                                 | The cells that a block of a grid covers.                    |
| `relative`                                                     | Layers, where each block lies over the last.                |
| `absolute`, `inset-0`, `top-0`, `right-0`, `bottom-0`, `left-0` | A layer pinned to its box, or to one edge of it.           |
| `hidden`, `flex`                                               | A block that doesn't show, and one that does.               |
| `items-start`, `items-center`, `items-end`, `items-stretch`    | Where a box places its blocks across its line.              |
| `justify-start`, `justify-center`, `justify-end`, `justify-between` | Where a box places its blocks along its line.          |
| `self-start`, `self-center`, `self-end`, `self-stretch`        | Where a block that's smaller than its box sits.             |
| `p-<s>`, `px-<s>`, `py-<s>`, `pt-<s>`, `pr-<s>`, `pb-<s>`, `pl-<s>` | The space inside a block, on each side or on some.     |
| `gap-<s>`, `gap-x-<s>`, `gap-y-<s>`                            | The space between the blocks of a box.                      |
| `w-<s>`, `h-<s>`, `size-<s>`, `min-w-<s>`, `max-w-<s>`         | The width, the height, or both.                             |
| `grow`                                                         | A block that takes the free space of its row or column.     |
| `shrink-0`                                                     | A block that never gets smaller than its content.           |
| `aspect-square`                                                | A block as high as it is wide.                              |
| `font-title`, `font-detail`, `font-metric`, `font-value`       | The fonts of a card's title, detail, metric and value.      |
| `font-section`                                                 | The look of a title over a group of blocks.                 |
| `font-medium`, `font-semibold`, `font-bold`                    | The weight of the words.                                    |
| `text-left`, `text-center`, `text-right`                       | Where the words sit inside the block's area.                |
| `truncate`, `line-clamp-<n>`                                   | Words cut with … at one line, or at `<n>` lines.            |
| `tabular-nums`                                                 | Digits that all take the same width.                        |
| `sr-only`                                                      | Words that don't show.                                      |
| `text-ink`, `text-secondary`, `text-accent`                    | The colour of words, its second colour, and the accent.     |
| `text-good`, `text-warn`, `text-bad`                           | The colour of words of each tone.                           |
| `bg-tile`, `bg-accent`, `bg-transparent`                       | The box that Openspot draws for a block: a tile, the main button, or none. |
| `bg-good`, `bg-warn`, `bg-bad`                                 | A fill of each tone.                                        |
| `backdrop-blur`                                                | A blur of what lies under the block, with the Mac's material. |
| `opacity-<p>`                                                  | The opacity of the block.                                   |
| `rounded-card`, `rounded-inner`, `rounded-full`, `rounded-none` | The corner of a block.                                     |
| `border`                                                       | A line around the block.                                    |
| `overflow-hidden`                                              | A block that cuts what passes its edge.                     |

- `<s>` is a step of Tailwind's scale from `0` to `96`, such as `3` or `0.5`, and each step is 4 points. `part` and
  `group` are the gaps of Openspot's own sheets, as in `gap-part`.
- A size also takes `full`, the whole width or height of its box, a share such as `1/2`, `1/3`, `2/3`, `1/4` or `3/4`,
  and `px`, the height of a divider.
- `<n>` is a count from 1 to 12, and `<p>` a percent from 0 to 100 in steps of 5.
- `bg-accent`, `bg-tile` and `bg-transparent` choose the box of a `button`, a `field`, a `switch`, a `choice`, a
  `number` or a `series`.
- `rounded-full` on a button makes a chip as wide as its words, or a round button of its `icon` when it has no `title`.
- No class draws glass.
- A class that isn't here, such as the free value `w-[120px]`, is skipped, and `openspot check spots` reports it.

## Variants

A variant is a prefix that applies a class only in a place or a state, as Tailwind's `hover:` does.

```ini
button=play
title=Play
class=bg-tile hover:bg-accent card:hidden
```

| Prefix                                           | Applies                                                       |
| ------------------------------------------------ | ------------------------------------------------------------- |
| `sheet:`, `card:`, `bar:`, `float:`, `window:`   | In that [place](#places), with `card:` on a card of any size. |
| `small:`, `wide:`, `square:`, `strip:`, `large:` | On a card of that size.                                       |
| `hover:`                                         | While the pointer is over the block.                          |
| `pressed:`                                       | While the block is pressed.                                   |
| `selected:`                                      | While the block's item is selected.                           |
| `focus:`                                         | While the block has the keys.                                 |
| `dark:`, `light:`                                | In that appearance of the Mac.                                |

- Openspot applies a variant with no call to the spot.
- Prefixes combine, such as `card:hover:bg-tile`, and the class then applies only when each of them does.
- A class with more prefixes wins over one with fewer, and a class with a prefix wins over the same class with none.

## Places

A place is where a frame shows. One frame draws every place, and [variants](#variants) lay out each one.

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

| Place                                       | Is                                                           |
| ------------------------------------------- | ------------------------------------------------------------ |
| `small`, `wide`, `square`, `strip`, `large` | A card in the panel, of the size that the person chooses.    |
| `bar`                                       | The menu bar, next to the clock.                             |

- The sheet shows the spot when the person opens it, and fills the panel.
- A float is a small window at the pointer, and a window is a normal window that holds the sheet. Both draw as the
  sheet does, with their own variants.
- The person chooses the places, as [Choose where a spot shows](USING.md#choose-where-a-spot-shows) says, and the spot
  only lays out the ones it cares about.

### The card

The card stands for the spot in the panel.

- A card draws the frame's tree once a class names `card:` or the card's size. With no such class, it shows the spot's
  icon, title and detail.
- The card's value is the one `text`, `number`, `series`, `switch` or slider that shows on it, or else the one among the
  items. When the card shows more than one, `value=<id>` in the root names it, and `openspot check spots` reports a
  card that shows more than one with no `value`.
- A switch that the card places shows its own value, and doesn't fill the card.
- A press on a switch that the card places flips it. When a switch or a slider is all that the card places, a press
  anywhere on the card changes it.
- Any other press does what Return does.
- The card's title and detail come from the root, or else from the manifest, never from a block that it places.

### The menu bar

The menu bar shows the spot's value small, beside the clock, once a class names `bar:`, such as `class=bar:flex` on a
`number`.

- It shows the first value that shows on `bar:`, or the one that `value` in the root names.
- A `number` with `type=ring` or `type=bar` is a small ring with its value, and any other `number` is its value.
- A `series` is its last 8 bars with its value.
- A `text` or an `item` with a `tone` and no `icon` is a dot of its tone and its title. Any other `text` or `item` is
  its title.
- With no class that names `bar:`, the menu bar shows the spot's icon.
- A `switch` or a slider that shows on `bar:` hides the spot there.
- A show that prints nothing hides the spot in the menu bar until the next show.
- A click opens the sheet under it.

### The main search

The main search is the panel's own search field, which lists items from every spot.

- `search = true` in `[on]` adds the items of the spot's `show`. With no `panel.open` or `every` in `[on]`, Openspot
  asks for them when it loads the spots and at each open of the sheet.
- `search = "<pattern>"` calls `search` at each change of a text that matches, with the text as `text`, and each text
  the person may have meant, such as in another keyboard layout, as `alt`.
- A newer text stops the older call.
- The items of `search` show first, or under the others with `answers = "last"`.
- `answers = "card"` shows one card in place of the items: the card of the frame's [value](#the-card), large when a
  class names `large:` and a strip otherwise. A press calls `press` with that value as `item`.
- A frame with no value still shows its items.
- A spot whose only trigger is `search` has no card.

### Slash commands

A slash command is a row `/<word>` of the main search, which runs the spot with the text the person typed, in one Return.

- `command = ["<word>"]` in `[on]` gives the spot its words. Return on a row calls `command` with the word as `name`, and
  the rest of the line, the words before and after it, as `text`, even when no text follows.
- `/` with a letter after it lists the words, the actions with a `title`, and the `scope=spot` buttons of a sheet, whose
  name matches. `/` alone lists them all.
- A word that matches none stays text, and an action with `confirm` isn't listed.
- A first frame whose root has `type=form` is a form, whose values go to `command` with the same `name`. Any other
  frame opens the sheet, and a frame with nothing to show, or the end of the call, closes the panel.
- The person can rename or remove each word, and `command` still gets the spot's own word as `name`.

## Pages

A page is a sheet of the spot that a route names, such as `photo/12` for the detail of an item.

```toml
pages = ["photo/*"]
```

```ini
item=12
title=Beach
route=photo/12
```

- `pages` in the manifest lists the routes that the spot may show, where `*` stands for any text.
- A press of an item with a `route` opens that route at once, with no call.
- Each call of a sheet with a route gets it as the input `route`.
- A spot with no sheet gets `press` with the route as `item` in place of a page.
- `openspot route push <route>` shows a route over the sheet that shows, and `--replace` replaces it.
- `openspot route back` takes the spot's sheet off, as Esc does, and with `--root` goes back to its first sheet.
- `openspot route close` takes each sheet of the spot off.
- A spot moves only its own routes, while its sheet shows. It never takes off another spot's sheet and never closes the
  panel, and a read never moves between sheets.

## Forms

A form is a frame that asks the person for values, and sends them to a handler.

```ini
frame=
type=form
title=Rename

field=name
title=Name
value=Home
```

- A form's root has `type=form` and a `title`, with a `field`, `choice` or `switch` for each value.
- Its values go to the same handler: the same action, `press` for a form that answered a press of an item, or
  `command` with the same `name` for a form that answered a slash command.
- A submit of a form passes the item as `item`.
- A handler that answers a form with `error=<message>` keeps it open with the message.
- A form whose only field is a `choice` lists its options, which the person searches, and Return sends the selected one.
- When the person runs an action whose required input is empty and has no default, Openspot draws a form from the
  types: a `bool` is a switch, a `choice` a menu of its `options`, and any other type a field.
- In a drawn form, each field takes the input's `default` as its value and its `description` as its placeholder. An
  empty field counts as no value, so its default applies.
- A global key shows no panel, so the call it makes fails with a line that names the empty input.
- The words typed after a button in the main search fill the first required `text` input of its action, or its first
  `text` input when none is required. When another required input is still empty, Openspot asks with the drawn form.
- When a search of the sheet finds no item, Return offers the first `scope=spot` button whose action has a `text` input,
  or else the first action with a `title` and such an input.
- That Return opens the drawn form with the searched words in the input when the action has a required input, and a
  second Return runs it. With none, Return calls the action with the words.

## Views

A view is a kind of block that a SwiftUI file of the spot draws, for a look or a motion that classes can't give.

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

- Each file of `views` in the manifest is a kind, named by its file: `views = ["liquid.swift"]` gives `liquid=<id>`.
- A view takes `parent` and `class` like any block, and fills the room its classes give it. With no height, it takes
  the free height.
- A key of the block can repeat, and `spot.all` reads each value.
- A file named like a kind of Openspot, such as `text.swift`, is a fault.
- The file must declare `struct SpotView: View` with `let spot: SpotInput`, with no top-level code and no method
  `update()`.

| Member                                          | Is                                                                                  |
| ----------------------------------------------- | ----------------------------------------------------------------------------------- |
| `spot["key"]`                                   | The last value of a key of its block, or nil.                                       |
| `spot.all("key")`                               | Each value of a key of its block.                                                   |
| `spot.size`                                     | The width and height of its area.                                                   |
| `spot.card`                                     | The name of its card's size, such as `wide`, or nil off a whole card.               |
| `spot.inset`, `spot.corner`                     | The space a card keeps inside its edge, and its corner radius.                      |
| `spot.ink`, `spot.secondary`, `spot.accent`     | The colour of words, the opacity of a second line, and the accent colour.           |
| `spot.font`                                     | The fonts of the cards: `title`, `detail`, `metric` and `value`.                    |
| `spot.theme`                                    | The values of the theme, in the groups below.                                       |
| `spot.send(v)`                                  | A run of the handler that the block's id names, with `v` as `value`.                |
| `spot.answers`                                  | A count that changes at each answer to a send, to end a busy state.                 |
| `spot.card(id)`, `spot.cardSize(id)`            | The card of a spot, by the id that `openspot store list` prints, and its size.      |
| `spot.sheet(id)`                                | The sheet of a spot from its `sample.sh`, where a press runs nothing.               |
| `spot.tip(text)`, `spot.tipDelay`               | A tip in the look of Openspot's own, to show on hover, and its delay.               |
| `spot.media(path)`                              | A PNG, JPEG or GIF picture, or a MOV or MP4 video, at its size or less.             |
| `spot.loop(...)`                                | A shape that moves in a loop, played by macOS.                                      |
| `spot.cornerButton`                             | The round button on the rim of a card, by its id and an action.                     |
| `spot.columnGap`, `spot.rowGap`, `spot.columns` | The gaps between cards, and how many columns of cards a window holds.               |
| `spot.items`, `spot.selection`                  | Each item of the frame, in a sheet or a window, and the id of the selected one.     |
| `spot.isShown`                                  | Whether its place shows now.                                                        |
| `spot.close()`                                  | A close of the sheet, the float or the window of its own spot.                      |
| `SpotMetric(spot, value:, detail:, mark:, onFill:)` | A big number with its detail and an SF Symbol `mark`.                           |

| Member              | Is                                                                                                     |
| ------------------- | ------------------------------------------------------------------------------------------------------ |
| `spot.theme.color`  | The colours `ink`, `solid`, `onSolid`, `accent`, `good`, `warn` and `bad`, and the strengths `secondary`, `fill`, `selected` and `track`. |
| `spot.theme.space`  | The sizes `padding`, `columnGap`, `rowGap`, `listRow`, `listRowGap`, `glyph`, `cell` and `gridWidth`.  |
| `spot.theme.radius` | The corners `card`, `media` and `inner`.                                                               |
| `spot.theme.font`   | The fonts `title`, `body`, `detail` and `input`.                                                       |
| `spot.theme.motion` | `press`, the time of a press in seconds, and `pressBounce`, its bounce.                                |

- The view gets the keys of its block in each frame, and keeps its `@State`.
- On a card, a view only draws. In a sheet, it takes clicks and keys.
- `spot.isShown` is false while the panel is hidden.
- `spot.loop(period:fill:path:)` and `spot.loop(period:stroke:width:path:)` draw a shape at each time from 0 to
  `period`, and the shape at `period` must equal the one at 0. It plays only while `spot.isShown` is true.
- Openspot removes a view while its place is hidden, unless it reads `spot.isShown`. It then stops its timers and its
  motion while that is false.
- `spot.theme`: each colour and strength is the one of the appearance that shows. `cell` is the side of a grid cell,
  and `inner` is the corner of a part that sits `padding` inside the card or the sheet.
- Openspot compiles the view at its first show and when the file changes. A shared spot carries it as
  `<name>.<hash>.view`, used while the hash matches.
- The view runs inside Openspot, so a crash quits Openspot. [Stats](app/Help/stats.md) counts each run of its `body`.

## The openspot command

`openspot <noun> <verb>` is the one way a spot asks the Mac and Openspot for anything, and it works the same in a
terminal. [The openspot commands](app/Help/commands.md) lists each one.

```text
$ openspot calc solve 2+2
item=4
title=4
```

- A noun names its commands, its events and its use, such as `openspot clipboard copy`, `clipboard.change` and
  `clipboard` in `uses`.
- A command exits 0 when it's done, 1 when it failed, 2 when `openspot` doesn't take its words, 3 when Openspot didn't
  answer, and 4 when the person closed what it showed.
- A wrong type, an undeclared binding and an undeclared event are words that `openspot` doesn't take.
- A command that has no answer prints `status=<word>`. A list or a report prints blocks, or JSON with `--json`.
- A read must never change anything or open anything, so a command that waits for the person, captures the screen,
  changes the Mac, Openspot or the sheets that show, or opens a window fails in it; see
  [the commands that fail in a read](app/Help/commands.md#the-commands-that-fail-in-a-read).
- `openspot toast <words>` shows the words for a moment, and `openspot select <item>` selects an item once the next
  frame shows. They work for the call that ran them, and do nothing when it's out of date.
- From a terminal, `toast`, `select` and `route` work on the sheet that shows.
- Each command declares its inputs and outputs, so `openspot spot actions` lists the commands of a spot's uses, and
  `openspot types` types them for its code.
- Openspot knows the calling spot by the link on descriptor 11 of its process; see [Uses](TRUST.md#uses).

### openspot run

`openspot run <binding>.<action> [<name>=<value>...]` runs an action of a spot that this spot [binds](#bindings), and
waits for its values.

```text
$ openspot run picker.pick title="Remind me later" --out until
2026-11-24T09:00:00+01:00
```

- It prints the values as `out.<name>=` lines, or with `--out <name>` each value of that output on a line of its own.
- `--stdin <name>` reads that input from stdin, for a value that is long or has lines.
- It checks the binding, the action and the inputs before the call, and the outputs after it.
- It exits 2 for an undeclared binding, an unknown action, an undeclared input or a wrong type, 1 with its line for a
  bound spot that doesn't load or a failure, and 3 for an action with outputs that gives none.
- An action that answers with a view shows it over the sheet that shows, as a step of its flow, titled by the `title`
  of its frame's root.
- The run ends, and the view leaves, at the first frame of the bound spot that holds `out.<name>` lines or `error=`.
- A close or a step back from the view exits 4, and in JavaScript resolves to `null`.
- When the person placed the bound spot in a window, the view shows in that window, and the window closes at the end
  of the run if the run opened it. A close of the window exits 4.
- A run that waits for the person or another spot doesn't count against its spot's time limit.
- A handler that the person didn't press, such as `show`, `schedule`, a timer or an event, can run a bound action, but
  the action can't show a view there: the run exits 2 with a line that says it needs the person.
- A run to a spot that is already in its chain, such as A, B, then A, exits 2 and names the chain, and so does a chain
  of more than 4 runs. A press, a key or a form starts a new chain.
- A process with no link on descriptor 11 can't use `openspot run`.

### openspot emit

`openspot emit <event> [<name>=<value>...]` sends one of the spot's [`[events.<name>]`](#eventsname) to the spots that
bind it.

```text
$ openspot emit finished minutes=25
```

- It checks the values as `openspot run` checks inputs: an undeclared value, a missing required one or a wrong type
  exits 2 and calls no spot.
- Each loaded spot that binds the sender and lists `<binding>.<event>` in its `[on]` gets one call, whether or not the
  panel shows.
- A process with no link on descriptor 11 can't use `openspot emit`.

### openspot timer

`openspot timer add <time> <action> [<name>=<value>...]` adds a timer, which runs an action of the spot at a time, even
when the panel is closed. It needs `timer` in `uses`.

```text
$ openspot timer add 2026-11-24T09:00:00+01:00 remind words="Time to stretch"
3F2A
```

- The time is ISO 8601 with its offset, such as `2026-11-20T08:00:00+01:00`, and the command prints the timer's id.
- Openspot checks the inputs when you add the timer: an unknown action, an undeclared input, a word with no `=`, a
  wrong type or a missing required input exits 2.
- A time that has passed comes due at once, such as after the Mac slept or Openspot was quit.
- `someday` keeps a timer that never comes due, until `openspot timer remove`.
- A due timer runs its action as a press that the person didn't make, and Openspot draws nothing that the call prints.
- `openspot timer list` prints each timer of the spot as an item, with its action as the `title`, its time in `at`, and
  each input as `input.<name>=`.
- `openspot timer remove <id>` removes one.
- A timer belongs to the spot that added it, and no other spot sees it. It lasts until it comes due, also across a
  restart.
- A spot holds at most 1000 timers, each with inputs of 4 KB or less.
- A timer of a spot that is off or gone comes due into nothing.

## Versions

The version at the top of this page is the version of the protocol.

- A new word raises the minor number, such as `3.1`.
- A change that breaks a spot raises the major number, such as `4.0`.
- A `draft` version may still change the meaning of a word. A version becomes `final` when real use proves it, and a
  `final` version never changes the meaning of a word.
- An older Openspot skips a word of a frame that it doesn't know, and doesn't load a spot whose manifest has a key that
  it doesn't know.
