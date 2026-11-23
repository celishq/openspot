# Settings

`draft` `optional` · Builds on [01](01-spot.md) and [06](06-actions.md#types) · Uses [09](09-commands.md)

Use this when the person should choose how your spot works, such as the city of a clock or the key of a web service.
A setting is a choice that the person makes in your spot's Settings, and that Openspot keeps for you. The
`[settings]` table declares them.

```toml
title = "Team clock"
icon = "clock"

[settings]
zone = { type = "choice", title = "City", options = ["Asia/Tokyo", "Europe/London", "America/New_York"], default = "Asia/Tokyo" }
```

```sh
#!/bin/sh
. "$OPENSPOT_SH"
zone=$(value setting.zone)
case "$1" in
  show) openspot_item time "$(TZ="$zone" date +%H:%M)" "$zone" ;;
esac
```

The sheet shows one row, the time in Tokyo, with Asia/Tokyo under it. `⌘` Return on the card opens its Settings, where
City is a menu of the three zones.

## [settings]

| Key           | Type     | Is                                                         |
| ------------- | -------- | ---------------------------------------------------------- |
| `type`        | text     | The [type](06-actions.md#types) of the value, required.    |
| `title`       | text     | The words of its row in the spot's Settings.               |
| `icon`        | text     | The icon of the setting.                                   |
| `default`     | its type | The value while the person has set none.                   |
| `description` | text     | What the setting is for.                                   |
| `options`     | [text]   | The values that a `choice` offers.                         |

- Each call gets each setting on stdin as `setting.<name>=`, or its default.
- Openspot shows and keeps a `choice` or a `bool` itself. Return on any other setting calls the handler of its name,
  which can ask with `openspot folder pick` or a form, and keep the value with `openspot setting set <name> <value>`.
- A setting MUST NOT be named `icon`, `enabled`, `menubar`, `open`, `float` or `key.<action>`.

## Secrets

A `secret` is a setting such as a key of a web service, which Openspot keeps in the Keychain and asks for in its own
form.

```toml
title = "Weather"
icon = "cloud.sun"
uses = ["network"]

[settings]
key = { type = "secret", title = "API key" }
```

- A secret never comes on stdin. Read it with `openspot setting get <name>`.
- No other spot and no terminal can read it; see [Uses](../../TRUST.md#uses).
