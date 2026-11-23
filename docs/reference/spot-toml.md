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
| `icon`     | text   | An SF Symbol, an emoji, or an image file of the folder.                                    |
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
is missing still runs, and people see a message about it once a day. In Careful mode, it fails.

| Use         | Lets your spot                                                                       |
| ----------- | ------------------------------------------------------------------------------------ |
| `app`       | Change Openspot itself: quit or update it, or change its theme, its keys or the menu bar. |
| `spots`     | Add, remove, change or run other spots, read their logs, and read or change their settings. |
| `screen`    | Take a picture or a recording of the screen, read or move windows, and pick a colour. |
| `clipboard` | Copy, paste and read the clipboard.                                                  |
| `calendar`  | Read and add events and reminders.                                                   |
| `power`     | Keep the Mac awake with its lid closed.                                              |
| `timer`     | Add, list and remove its timers.                                                     |
| `network`   | Reach the network in Careful mode, such as with `env.fetch`.                          |
| `files`     | Write outside its data folder in Careful mode. No command needs it.                  |

A program of the Mac, such as `open <url>`, isn't an `openspot` command, so it needs no use. [Uses](../../TRUST.md#uses)
lists each command that needs one, and [Careful mode](../../TRUST.md#careful-mode) says what it stops.

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

A setting can't take a name that Openspot keeps for people: `icon`, `enabled`, `menubar`, `open`, `float`, any
`key.<action>`, or a name of Openspot's own settings, such as `careful`.

## [actions.\<id\>]

One table for each thing your spot does by name. Openspot runs `<script> <id>` with its inputs.

| Key              | Type              | Is                                                     |
| ---------------- | ----------------- | ------------------------------------------------------ |
| `title`          | text              | The words people run it by. With none, it runs only from a button, a view, a timer or another spot. |
| `icon`           | text              | Its icon.                                              |
| `confirm`        | text              | The words that ask people to press a second time.      |
| `inputs.<name>`  | a type or a table | A value it takes.                                      |
| `outputs.<name>` | a type or a table | A value it gives back, as an `out.<name>=` line.       |

An action can't be named for a word Openspot runs, such as `show`, `press` or `drag`.

## An input

An input, an output or a value of an event takes a type alone, such as `url = "url"`, or a table with these keys.

| Key           | Type     | Default | Is                                                 |
| ------------- | -------- | ------- | -------------------------------------------------- |
| `type`        | text     |         | Its type. Required.                                |
| `required`    | bool     | `false` | Whether it can't be empty.                         |
| `default`     | its type | none    | The value it gets when it's given none. Not for a list. |
| `description` | text     | none    | What it is. A form shows it as the placeholder.    |
| `options`     | [text]   | none    | The values of a `choice`.                          |

## [bindings]

`name = { spot = "<id>" }` names one spot that your spot runs or listens to, such as
`picker = { spot = "openspot/snooze" }`. A name holds no space and no dot.

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
| `drop`                | [text]          | `drop`                            | When people drop a file of a kind on your card, such as `png`, `folder` or `*`. |
| `"cache.<name>"`      | an age          | `cache.<name>`                    | When a read of the cache `<name>` finds it missing or older than the age, such as `"1d"`; see [Keep a copy that goes old](../remember/cache.md). |

A regex on an event, such as `"power.change" = "^battery$"`, runs your spot only when the event's value matches.

## Events

| Event              | Runs    | Its `value`                      | Comes                                                     |
| ------------------ | ------- | -------------------------------- | --------------------------------------------------------- |
| `panel.open`       | `show`  | none                             | Each time the panel opens, and once when Openspot starts. |
| `sheet.open`       | `show`  | none                             | Each time your spot's sheet opens.                        |
| `spot.want`        | `show`  | none                             | When a card or the search first shows your spot in an open of the panel. |
| `sheet.text`       | itself  | the text                         | At each change of the text in your sheet's search field.  |
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
