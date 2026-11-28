# Answer when the Mac changes

You'll build Power, which shows whether your Mac runs on power or on battery. Pull the cable, and it changes at once.

## Make the spot

`power.spot/spot.toml`:

```toml
title = "Power"
icon = "bolt"

[on]
"panel.open" = true
"power.change" = true
```

`power.spot/power.sh`:

```sh
#!/bin/sh
case "$1" in
  show) pmset -g batt | grep -q "'AC Power'" && power=ac || power=battery ;;
  power.change) power=$(sed -n 's/^input.value=//p') ;;
  *) exit 0 ;;
esac
if [ "$power" = ac ]; then
  printf 'item=power\ntitle=On power\nicon=powerplug\n'
else
  printf 'item=power\ntitle=On battery\nicon=battery.50\n'
fi
```

Open Power. It shows On power. Pull the cable while it's open, and it shows On battery.

## How it works

When the power changes, Openspot runs `power.sh power.change` and sends what changed on stdin:

```ini
input.value=battery
```

Your script prints what to show, as `show` does. Openspot runs it only while the spot shows: its card in the open
panel, its sheet, its float or the menu bar. So an event costs nothing while the panel is closed. A spot with
`timeline` in its `uses` gets its events at all times, so its [timeline](../remember/timeline.md) misses nothing.

`"panel.open" = true` runs `show` each time the panel opens, so Power is right even after a change it missed.
That run gets `input.event=panel.open` on stdin.

When people open your sheet, Openspot runs `show` again only if the last run was 5 seconds ago or more.
`"sheet.open" = true` runs it each time the sheet opens.

An event's run only shows. It can't change the Mac or open anything, so a command such as `openspot clipboard copy`
fails in it. It can write to Openspot, such as `openspot timeline add`.

To answer only some values, give a regular expression instead of `true`:

```toml
[on]
"power.change" = "^battery$"
```

## Take a dropped file

`drop` lists the kinds of file people can drop on your card, such as `["png", "jpg"]`, `["folder"]` or `["*"]`:

```toml
[on]
drop = ["png", "jpg"]
```

Openspot runs `<script> drop` once, with one `input.file=` line for each file.

## The events

| Event              | `input.value`                   | Comes                                                  |
| ------------------ | ------------------------------- | ------------------------------------------------------ |
| `panel.open`       | none, runs `show`               | Each time the panel opens.                             |
| `app.launch`       | none                            | Once when Openspot starts, shown or not.               |
| `clipboard.change` | none                            | When the clipboard changes.                            |
| `app.front`        | its bundle ID                   | When another app comes to the front.                   |
| `power.change`     | `ac`, `battery` or `ups`        | When the power source or the battery's percent changes. |
| `screen.wake`      | none                            | When the screen wakes.                                 |
| `disk.mount`       | its path                        | When a disk mounts.                                    |
| `device.connect`   | its name                        | When a USB device connects.                            |
| `calendar.change`  | none                            | When an event of your calendars, from yesterday to a year ahead, changes. |
| `reminders.change` | none                            | When a reminder changes.                               |
| `system.load`      | `cpu=<percent> memory=<percent>` | Every 5 seconds.                                       |

macOS tells no app when the clipboard changes, so Openspot looks for a new copy: each half second while the panel shows,
each second while you use the Mac, and each 10 seconds after half a minute with no key or click. It looks at once when
another app comes to the front, and not at all while the screen sleeps or is locked.

`calendar.change` and `reminders.change` come once after a burst of changes, such as a sync, and only once the person has
allowed Openspot to read Calendar or Reminders. They say only that something changed: read what you need with
`openspot calendar events` or `openspot reminders due`, as [its guide](../../app/Help/calendar.md) shows.

## Next

- [Run every minute or on a schedule](on-a-schedule.md)
- [Answer as people type](typing.md)
