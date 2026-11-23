# spot.toml

`spot.toml` says what a spot is called, what it can do and what calls it.

```toml
title = "Snooze Tab"
icon = "moon.zzz"
uses = ["timer"]

[settings]
browser = { type = "choice", options = ["Safari", "Chrome"], default = "Safari" }

[actions.snooze]
title = "Snooze Tab"
outputs.until = "date"

[on]
"sheet.open" = true
```

| Key        | Type   | Default           | Is                                                                         |
| ---------- | ------ | ----------------- | -------------------------------------------------------------------------- |
| `title`    | text   | the folder's name | The name of the spot.                                                      |
| `icon`     | text   | none              | An SF Symbol, an emoji, or an image file of the folder.                    |
| `detail`   | text   | none              | The line under the title.                                                  |
| `keywords` | [text] | none              | More words that find the spot in the search of the panel.                 |
| `uses`     | [text] | none              | The features of the Mac that the spot uses, from [Uses](../../TRUST.md#uses). |
| `stay`     | bool   | `false`           | Whether one process answers every call; see [A staying spot](12-modes.md#a-staying-spot). |
| `pages`    | [text] | none              | The routes that the spot may show; see [Pages](06-items.md#pages).         |
| `views`    | [text] | none              | The SwiftUI files of the spot; see [Views](14-views.md).                   |
| `source`   | [text] | none              | The Swift files that a [Swift spot](12-modes.md#a-swift-spot) is built from. |
| `answers`  | text   | none              | Where the answers of `search` show: `last` or `card`; see [The main search](11-places.md#the-main-search). |

The tables each have a page: `[settings]` and `[actions.<id>]` in [Actions and settings](07-actions-and-settings.md),
`[on]` in [Triggers](08-triggers.md), and `[bindings]` and `[events.<name>]` in
[Bindings and events](09-bindings-and-events.md).

- A wrong or unknown key, such as `titel`, keeps the spot from loading, and its fault names the key.
- `openspot schema` prints the JSON Schema of the file, and [`schema/spot.schema.json`](../../schema/spot.schema.json)
  holds a copy, which an editor such as one with Taplo checks the file with.
- The keys that only Openspot's own spots take are in [The app's own words](../../spots/AGENTS.md#the-apps-own-words).

## Types

Each input, output, setting and value of an event has a type.

| Type       | Value                                                                 |
| ---------- | --------------------------------------------------------------------- |
| `text`     | Any text.                                                             |
| `number`   | A number, such as `4` or `2.5`.                                       |
| `bool`     | `true` or `false`.                                                    |
| `date`     | An ISO 8601 day or time, such as `2026-11-22T09:00:00Z`.              |
| `duration` | A number of seconds.                                                  |
| `url`      | A web address.                                                        |
| `file`     | A path that starts with `/`.                                          |
| `secret`   | A text of 8 characters or more, kept in the Keychain.                 |
| `choice`   | One of its `options`.                                                 |
| `[<type>]` | A list of values of that type, such as `[file]`, one line for each.   |

## An input

A value takes a type alone, such as `url = "url"`, or a table:

```toml
[actions.wake]
inputs.url = { type = "url", required = true, description = "The tab to open again" }
```

| Key           | Type     | Default  | Is                                                       |
| ------------- | -------- | -------- | -------------------------------------------------------- |
| `type`        | text     | required | The type of the value.                                   |
| `required`    | bool     | `false`  | Whether the value must not be empty.                     |
| `default`     | its type | none     | The value that a call gets when it's given none.         |
| `description` | text     | none     | What the value is, which a form shows as its placeholder. |
| `options`     | [text]   | none     | The values that a `choice` offers.                       |

- A list type takes no `default`.
