# Triggers

`draft` `optional` · Builds on [01](01-spot.md) · Uses [05](05-places.md#the-main-search), [06](06-actions.md#forms) and [10](10-other-spots.md)

Use this when your spot should run without a press: when the panel opens, on a clock, when the Mac changes, or from a
slash command or a file the person drops. A trigger calls your spot by itself, and the `[on]` table lists them.

```toml
title = "Notes"
icon = "note.text"

[on]
"panel.open" = true
command = ["note"]
```

```sh
#!/bin/sh
. "$OPENSPOT_SH"
notes="$OPENSPOT_DATA/notes"
case "$1" in
  show) tail -n 5 "$notes" 2>/dev/null | awk '{ print NR "\t" $0 }' | openspot_items ;;
  command) printf '%s\n' "$(value text)" >> "$notes" ;;
esac
```

Each open of the panel calls `show`, which lists the last five notes in the sheet. `/note buy milk` in the panel's
search calls `command` with `input.name=note` and `input.text=buy milk`.

## [on]

| Key                   | Value           | Calls                        | Is                                                    |
| --------------------- | --------------- | ---------------------------- | ----------------------------------------------------- |
| `"<event>"`           | `true` or regex | `<spot> show` or `<spot> <event>` | An [event](#events) that the spot listens to.    |
| `"<binding>.<event>"` | `true`          | `<spot> <binding>.<event>`   | An event of a spot that it [binds](10-other-spots.md). |
| `every`               | seconds         | `<spot> every`               | The time between calls while the spot shows.          |
| `schedule`            | [text]          | `<spot> schedule`            | Cron lines of the times to call the spot, shown or not. |
| `command`             | [text]          | `<spot> command`             | The words of its [slash commands](#slash-commands).   |
| `search`              | `true` or regex | `<spot> show` or `<spot> search` | The texts of the panel's search that it answers; see [The main search](05-places.md#the-main-search). |
| `drop`                | [text]          | `<spot> drop`                | The file extensions that its card takes, such as `png`, `folder` or `*`. |

- A regex is a regular expression that the event's value must match, such as `"^(ac|battery)$"`.
- `panel.open`, `sheet.open` and `spot.want` call `show` with the event as the input `event`. Each other event calls
  the handler of its own name, with its value as the input `value`.
- `every`, `search` and an event's handler are reads, like `show`, so they MUST NOT change or open anything.
- A spot with `every` starts off the grid, and one with `schedule` starts off until the person turns it on.
- An unknown event, or a filter on an event with no value, keeps the spot from loading.

## A clock

`every = 300` calls `every` every 5 minutes while the spot shows. `schedule` calls `schedule` whether it shows or not.

- A `schedule` line is minute, hour, day, month and weekday, such as `"0 9 * * 1-5"` for 9:00 each weekday.
- The call gets the line as `cron`, and as `late` the seconds since it was due. A time missed while the Mac slept
  runs once at wake.

## Events

| Event              | Value                            | Comes                                                     |
| ------------------ | -------------------------------- | --------------------------------------------------------- |
| `sheet.open`       | none                             | When the spot's sheet opens.                              |
| `panel.open`       | none                             | Each time the panel opens, and once when Openspot starts. |
| `sheet.text`       | the text                         | At each change of the text in the sheet's search field.   |
| `spot.want`        | none                             | When a card or the search first shows the spot in an open of the panel. |
| `clipboard.change` | none                             | When the clipboard changes.                               |
| `app.front`        | its bundle ID                    | When another app comes to the front.                      |
| `app.update`       | its version                      | When Openspot has downloaded an update.                   |
| `app.launch`       | none                             | Once when Openspot starts.                                |
| `screen.wake`      | none                             | When the screen wakes.                                    |
| `system.load`      | `cpu=<percent> memory=<percent>` | Every 5 seconds while the spot shows.                     |
| `power.change`     | `ac`, `battery` or `ups`         | When the power source or the battery's percent changes.   |
| `disk.mount`       | its path                         | When a disk mounts.                                       |
| `device.connect`   | its name                         | When a USB device connects.                               |

- An event calls a spot only while it shows, except `app.launch` and `app.update`, which call it either way. A
  `schedule`, a timer and an event of a bound spot call it whether or not it shows.
- The sheet calls `show` at each open, unless it called it less than 5 seconds ago. `"sheet.open" = true` calls it
  even then.

## Slash commands

A slash command is a row `/<word>` of the panel's search, which runs your spot with the text typed after it.

- `command = ["<word>"]` gives the spot its words. A word starts with a letter, and holds only letters, digits, `-`
  and `_`.
- Return calls `command` with the word as `name` and the rest of the line as `text`, even when it's empty.
- A first frame whose root has `type=form` asks with a [form](06-actions.md#forms). Any other frame opens the sheet,
  and the end of the call closes the panel.
- The person can rename a word, and `command` still gets the spot's own word as `name`.

## Drop

`drop = ["png", "jpg"]` lets the person drop files of those kinds on your card. Openspot then calls `drop` with each
path as `file`, once for each.
