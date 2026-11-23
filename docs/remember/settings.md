# Settings people choose

You'll build a team clock that shows the time in one city. People pick the city in the spot's Settings, and Openspot
remembers it for you.

## Make the spot

`clock.spot/spot.toml` declares the setting:

```toml
title = "Team clock"
icon = "clock"

[settings]
zone = { type = "choice", title = "City", options = ["Asia/Tokyo", "Europe/London", "America/New_York"], default = "Asia/Tokyo" }
```

`clock.spot/clock.sh` reads it:

```sh
#!/bin/sh
zone=$(sed -n 's/^setting.zone=//p')
case "$1" in
  show) printf 'item=time\ntitle=%s\ndetail=%s\n' "$(TZ="$zone" date +%H:%M)" "$zone" ;;
esac
```

Open Team clock. It shows the time in Tokyo, with Asia/Tokyo under it. Press `⌘` Return on its card to open its
Settings, and pick another city under City.

## How it works

Openspot sends each setting on stdin with every run, after the inputs:

```ini
setting.zone=Asia/Tokyo
```

Until someone picks a value, the line holds the `default`. A setting with no value and no default sends no line.

People find your settings in the spot's Settings, below its keys. Each row shows the setting's `title` and its value,
or Not set. `⌘⌫` removes the value.

Openspot asks for a `choice` itself, with a menu of its `options`, and for a `secret` in its own form. For any other
type, Return on the row runs your script with the setting's name, such as `clock.sh zone`. Ask there, and keep the
answer:

```text
openspot setting set zone Europe/London
```

`openspot folder pick` is one way to ask, for a folder. A [form](../act/forms.md) is another.

## Keep a secret

A key for a web service is a `secret`:

```toml
[settings]
key = { type = "secret", title = "API key" }
```

Openspot asks for it in its own form and keeps it in the Keychain. A secret never comes on stdin. Your spot reads it
with a command:

```text
openspot setting get key
```

Only your own spot gets the value. Any other spot, and any terminal, gets `•••`.

## The keys of a setting

| Key           | Is                                                                                         |
| ------------- | ------------------------------------------------------------------------------------------ |
| `type`        | `text`, `number`, `bool`, `date`, `duration`, `url`, `file`, `secret` or `choice`. Required. |
| `title`       | The name of its row in Settings. The setting's name with a capital first letter by default. |
| `default`     | The value until someone picks one.                                                         |
| `options`     | The values a `choice` offers.                                                              |
| `description` | What the setting is for.                                                                   |
| `icon`        | The icon of its row.                                                                       |

## Next

- [Keep your own data](data.md)
- [spot.toml](../reference/spot-toml.md)
