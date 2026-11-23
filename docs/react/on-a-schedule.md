# Run every minute or on a schedule

You'll build Stand-up. Its card counts down the minutes to your 9:30 stand-up, and at 9:25 on each weekday a message
reminds you, even when the panel is closed.

## Make the spot

`standup.spot/spot.toml`:

```toml
title = "Stand-up"
icon = "person.3"

[on]
every = 60
schedule = ["25 9 * * 1-5"]
```

`standup.spot/standup.sh`:

```sh
#!/bin/sh
case "$1" in
  show | every)
    left=$(date '+%H %M' | awk '{ print 9 * 60 + 30 - ($1 * 60 + $2) }')
    if [ "$left" -gt 0 ]; then
      printf 'frame=\ndetail=in %s min\n' "$left"
    else
      printf 'frame=\ndetail=Done for today\n'
    fi
    ;;
  schedule) openspot toast "Stand-up in 5 minutes" ;;
esac
```

A spot with a schedule starts off, so that a new spot never runs on its own. Turn it on:

```text
openspot setting set --spot standup enabled true
```

A new spot's card starts on the panel's grid, unless the spot has `every`, an action with a title, or only a `search`
pattern. Stand-up has `every`, so add its card in Edit Spots. At 8:05, the card shows Stand-up, with in 85 min under
it. At 9:25 on a weekday, a message says Stand-up in 5 minutes.

## How it works

`every = 60` runs `standup.sh every` each 60 seconds, but only while the spot shows: its card in the open panel, its
sheet, its float or the menu bar. When nothing shows it, nothing runs.

`every` prints what to show, as `show` does. Here that's the `detail` of the `frame=` block, the line under the
card's title. [A value on the card](../show/the-card.md) says more.

`schedule` runs `standup.sh schedule` at each time it names, whether the spot shows or not. Each line is cron: minute,
hour, day, month and weekday. `"25 9 * * 1-5"` is 9:25 from Monday to Friday. A spot can have several lines, and the
run gets the line that came due on stdin:

```ini
input.cron=25 9 * * 1-5
input.late=0
```

`late` is the seconds since it was due. A time missed while the Mac slept runs once when it wakes.

## Run once, at a time

For one time only, such as an hour from now, add a timer from any run. It runs an [action](../act/actions.md) of
your spot at that time, even after a restart, and needs `timer` in `uses`:

```text
openspot timer add 2026-11-24T09:25:00+01:00 remind words="Stand-up in 5 minutes"
```

`openspot timer list` prints your spot's timers, and `openspot timer remove <id>` removes one.

## The keys of `[on]`

| Key        | Runs                    | When                                       |
| ---------- | ----------------------- | ------------------------------------------ |
| `every`    | `<script> every`        | Each so many seconds, while the spot shows. |
| `schedule` | `<script> schedule`     | At each cron line, shown or not.           |

## Next

- [Answer when the Mac changes](mac-events.md)
- [Use the Mac: clipboard, screen, timers](../connect/the-mac.md)
