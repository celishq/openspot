# spot.toml

`spot.toml` names your spot and says what it adds. A key Openspot doesn't know keeps the spot from loading, and
`openspot check spots` names it. `openspot schema` prints the JSON Schema of the file, for your editor.

## The folder

A spot is a folder in `~/.config/openspot/spots`, such as `ports.spot`. Its id is the folder's name without `.spot`,
and it holds 64 MB at most. A spot you share holds 25 MB at most; see
[Share your spot](../further/share.md).

| File             | Is                                                                                  |
| ---------------- | ----------------------------------------------------------------------------------- |
| `spot.toml`      | This file. Required.                                                                |
| `<name>.<ext>`   | The script, named like the folder, such as `ports.sh` or `ports.js`. Required.      |
| `readme.md`      | The page the Store shows about your spot.                                           |
| `sample.sh`      | A script that prints what your spot shows, with made-up data.                       |
| `releases.jsonl` | The signed releases, which Openspot writes when you share; see [Signed releases](../../TRUST.md#signed-releases). |

People choose where your spot shows, as [Choose where a spot shows](../../MANUAL.md#choose-where-a-spot-shows) says.

## Keys

Each key of the top level, before the first table.

| Key        | Type   | Is                                                                                         |
| ---------- | ------ | ------------------------------------------------------------------------------------------ |
| `title`    | text   | The name of the spot. The folder's name by default.                                        |
| `icon`     | text   | An SF Symbol, an emoji, an image file of the folder, or a colour as `#rrggbb`, which shows as a square of it. |
| `detail`   | text   | The line under the title.                                                                  |
| `keywords` | [text] | More words that find the spot in the panel's search.                                       |
| `uses`     | [text] | What it needs from the Mac; see [Uses](#uses).                                             |
| `pages`    | [text] | The routes the spot may show, where `*` stands for any text, such as `["photo/*"]`.        |
| `answers`  | text   | Where its answers show in the panel's search: `"last"`, under the others, or `"card"`, as the card of the frame's value. First by default. It needs `search` in `[on]`. |
| `stay`     | bool   | Whether the script keeps running and gets each word on stdin. Not for a `.js` spot.         |
| `source`   | [text] | More Swift files or folders of a Swift spot.                                               |
| `views`    | [text] | The SwiftUI files that draw its own kinds of block, such as `["week.swift"]`.              |

## Uses

Each use lets your spot run some `openspot` commands. People see your uses when they add your spot. A command whose use
is missing fails, and Openspot tells people once a day.

| Use         | Lets your spot                                                                       |
| ----------- | ------------------------------------------------------------------------------------ |
| `app`       | Change Openspot itself: quit or update it, or change its theme, its keys or the menu bar. |
| `spots`     | Add, remove, change or run other spots, read their logs, and read or change their settings. |
| `screen`    | Take a picture or a recording of the screen, read or move windows, and pick a colour. |
| `clipboard` | Copy, paste and read the clipboard.                                                  |
| `calendar`  | Read and add events and reminders.                                                   |
| `power`     | Keep the Mac awake with its lid closed.                                              |
| `timer`     | Add, list and remove its timers.                                                     |
| `timeline`  | Add to its own timeline and read it back; see [Keep a timeline](../remember/timeline.md). |
| `attachment` | Put a value in the panel's field when the panel opens or Tab picks its chip; see [Attach what people work on](../connect/attachments.md). |
| `read`      | Read what people work on: the front tab, the files selected in Finder and the selected text. |
| `network`   | Reach the network, such as with `env.fetch`.                                         |
| `files`     | Write outside its data folder. No command needs it.                                  |

A program of the Mac, such as `open <url>`, isn't an `openspot` command, so it needs no use. [Uses](../../TRUST.md#uses)
lists each command that needs one, [What macOS gives Openspot](../../TRUST.md#what-macos-gives-openspot) the access of
macOS that each command needs, and [The sandbox](../../TRUST.md#the-sandbox) what `network` and `files` hold.

## Types

Each setting, input, output and value of an event takes one of these types.

| Type       | A value is                                                          |
| ---------- | ------------------------------------------------------------------- |
| `text`     | Any text.                                                           |
| `number`   | A number, such as `4` or `2.5`.                                     |
| `bool`     | `true` or `false`.                                                  |
| `date`     | An ISO 8601 day or time, such as `2026-11-22` or `2026-11-22T09:00:00Z`. |
| `duration` | A number of seconds, 0 or more.                                     |
| `url`      | An address with a scheme, such as `https://example.com`.            |
| `file`     | A path that starts with `/`.                                        |
| `secret`   | A text that Openspot keeps in the Keychain. Its form asks for 8 characters or more. |
| `choice`   | One of its `options`.                                               |
| `[<type>]` | A list of values of that type, such as `[file]`, one line for each. |

## [settings]

`name = "<type>"`, or `name = { ... }` with these keys, declares one choice people make in your spot's Settings.

| Key           | Type     | Is                                                   |
| ------------- | -------- | ---------------------------------------------------- |
| `type`        | text     | Its type. Required.                                  |
| `title`       | text     | The words of its row. The name, capitalised, by default. |
| `description` | text     | What it's for.                                       |
| `icon`        | text     | The icon of its row.                                 |
| `default`     | its type | The value until people choose one.                   |
| `options`     | [text]   | The values of a `choice`.                            |

A setting can't take a name that Openspot keeps for people: `icon`, `menubar`, `attachment`, `open`, `float`, `search`,
`grid`, `enabled`, `global`, `tray`, any
`key.<action>`, `window`, or a name of Openspot's own settings, such as `slow`.

## [actions.\<id\>]

One table for each thing your spot does by name. Openspot runs `<script> <id>` with its inputs.

| Key              | Type              | Is                                                     |
| ---------------- | ----------------- | ------------------------------------------------------ |
| `title`          | text              | The words people run it by. With none, it runs only from a button, a view, a timer or another spot. |
| `icon`           | text              | Its icon.                                              |
| `confirm`        | text              | The words that ask people to press a second time.      |
| `offers`         | [text]            | `["attachments"]`: it shows only as a row for a chip, not in the search, the `⌘K` menu or the keys. See [Offer an action](../connect/attachments.md#offer-an-action). |
| `inputs.<name>`  | a type or a table | A value it takes.                                      |
| `outputs.<name>` | a type or a table | A value it gives back, as an `out.<name>=` line.       |

An action can't be named for a word Openspot runs, such as `show`, `press` or `drag`.

## An input

An input, an output or a value of an event takes a type alone, such as `url = "url"`, or a table with these keys.

| Key           | Type     | Default | Is                                                 |
| ------------- | -------- | ------- | -------------------------------------------------- |
| `type`        | text     |         | Its type, or the name of one of your [types](#typesname) for an input. Required. |
| `required`    | bool     | `false` | Whether it can't be empty.                         |
| `default`     | its type | none    | The value it gets when it's given none. Not for a list. |
| `description` | text     | none    | What it is. A form shows it as the placeholder.    |
| `options`     | [text]   | none    | The values of a `choice`.                          |
| `pattern`     | text     | none    | A regular expression that each value must match. Only for a `url` or a `text`. |

## [bindings]

`name = { spot = "<id>" }` names one spot that your spot runs or listens to, such as
`picker = { spot = "openspot/snooze" }`. A name holds no space and no dot.

## [types.\<name\>]

One table for each kind of value your spot knows, such as a colour. A row of any sheet whose `text=` or `url=` matches
`match` is of the type: its preview comes from your spot's `item.preview`, with `input.type=<name>`. An action whose
required input has the type, such as `inputs.color = { type = "color", required = true }`, shows in the `⌘K` menu of
such a row and under such a chip, and not in the search. Openspot tests a row when people show it, so older rows gain a new type
too. A spot with types whose `[on]` holds only `item.preview` stays off the grid and out of the search.
See [Show a preview of a row](../show/preview.md#give-a-type).

| Key     | Type | Is                                                          |
| ------- | ---- | ----------------------------------------------------------- |
| `title` | text | The type's name for people, such as `Color`. Required.      |
| `match` | text | A regular expression of the whole value. Required.          |

## [events.\<name\>]

One table for each piece of news your spot sends with `openspot emit`. Each key of the table is one value of the event,
with its type or an input table. A name holds no space and no dot.

## [on]

When Openspot runs your spot by itself.

| Key                   | Value           | Runs                              | When                                                     |
| --------------------- | --------------- | --------------------------------- | -------------------------------------------------------- |
| `"<event>"`           | `true` or regex | `show`, or the event's own name   | When the event comes; see the next table.                |
| `"<binding>.<event>"` | `true`          | `<binding>.<event>`               | When a spot you bind sends the event.                    |
| `every`               | seconds         | `every`                           | Again and again while the spot shows, such as `every = 60`. |
| `schedule`            | [text]          | `schedule`                        | At each cron line, such as `"0 9 * * 1-5"`, shown or not. |
| `command`             | [text]          | `command`                         | When people type `/<word>` in the panel's search.        |
| `search`              | `true` or regex | `show`, or `search`               | `true` adds your items to the panel's search. A regex runs `search` for each text that matches. |
| `drop`                | [text]          | `drop`                            | When people drop a file of a kind on your card, such as `png`, `folder` or `*`, or hand it a file chip with Tab. A [chip](../connect/attachments.md#how-it-takes-it) of a `url` or a `text` goes to an action. |
| `"attachment.pick"`   | regex or `"browsers"` | `attachment.pick`           | In a source, when Tab first picks its chip in an open of the panel over an app whose bundle ID matches, or with `"browsers"` over any browser that Openspot reads; see [Attach what people work on](../connect/attachments.md). |
| `"cache.<name>"`      | an age          | `cache.<name>`                    | When a read of the cache `<name>` finds it missing or older than the age, such as `"1d"`; see [Keep a copy that goes old](../remember/cache.md). |

A regex on an event, such as `"power.change" = "^battery$"`, runs your spot only when the event's value matches.

## Events

| Event              | Runs    | Its `value`                      | Comes                                                     |
| ------------------ | ------- | -------------------------------- | --------------------------------------------------------- |
| `panel.open`       | `show`  | the bundle ID of the front app   | Each time the panel opens, and once when Openspot starts. |
| `sheet.open`       | `show`  | none                             | Each time your spot's sheet opens.                        |
| `spot.want`        | `show`  | none                             | When a card or the search first shows your spot in an open of the panel. |
| `sheet.text`       | itself  | the text                         | At each change of the text in your sheet's search field.  |
| `item.preview`     | itself  | none                             | When `⌘Y` shows the preview of a row; see [Show a preview](../show/preview.md). |
| `clipboard.change` | itself  | none                             | When the clipboard changes.                               |
| `app.front`        | itself  | its bundle ID                    | When another app comes to the front.                      |
| `app.update`       | itself  | its version                      | When Openspot has downloaded an update.                   |
| `app.launch`       | itself  | none                             | Once when Openspot starts.                                |
| `screen.wake`      | itself  | none                             | When the screen wakes.                                    |
| `system.load`      | itself  | `cpu=<percent> memory=<percent>` | Every 5 seconds while your spot shows.                    |
| `power.change`     | itself  | `ac`, `battery` or `ups`         | When the power source or the battery's percent changes.   |
| `disk.mount`       | itself  | its path                         | When a disk mounts.                                       |
| `device.connect`   | itself  | its name                         | When a USB device connects.                               |

An event reaches your spot only while it shows, except `app.launch` and `app.update`.

## The app's own keys

`edits`, `starts`, `[scripts.<name>]`, and `offers`, `shortcut`, `close` and `when` in an action, work only in
Openspot's own spots; see [The app's own words](../../spots/AGENTS.md#the-apps-own-words).
