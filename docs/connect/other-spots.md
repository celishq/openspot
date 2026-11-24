# Use another spot

You'll build Remind me, which asks when to remind you and then does. It doesn't draw its own time picker. It borrows
Snooze, one of Openspot's own spots.

## Make the spot

`remind.spot/spot.toml`:

```toml
title = "Remind me"
icon = "bell"
uses = ["timer"]

[bindings]
picker = { spot = "openspot/snooze" }

[actions.remind]
inputs.words = { type = "text", required = true }
```

`remind.spot/remind.sh`:

```sh
#!/bin/sh
case "$1" in
  show) printf 'button=later\ntitle=Remind me later\nscope=spot\n' ;;
  later)
    picked=$(openspot run picker.pick title="Remind me later" --out until)
    case $? in 0) ;; 4) exit 0 ;; *) exit 1 ;; esac
    openspot timer add "$picked" remind words="Look at this again"
    ;;
  remind) openspot toast "$(sed -n 's/^input.words=//p')" ;;
esac
```

Choose Remind me later in the `⌘K` menu. The tiles of Snooze show over your sheet. Pick Tomorrow, and tomorrow a
message says Look at this again.

## How it works

`[bindings]` gives another spot a name in your spot, here `picker`. People approve each binding when they add your
spot. Openspot's own spots have ids such as `openspot/snooze`. Any other spot's id is the name of its folder.

`openspot run picker.pick` runs the action `pick` of Snooze and waits. Its tiles show over your sheet. When people
pick one, it prints the time:

```text
2026-11-24T09:00:00+01:00
```

`--out until` prints only the output `until`, one value a line. Without it, each output prints as `out.<name>=`.

The `case $?` line reads how the run ended:

| Code | Means                                                        |
| ---- | ------------------------------------------------------------ |
| `0`  | Done. The values are on stdout.                              |
| `1`  | The other spot failed.                                       |
| `2`  | No such binding, action or input, or a value of the wrong type. |
| `4`  | People closed what it showed. That's not a failure, so end with `exit 0`. |

To see what you can run, print a spot's actions with their inputs and outputs:

```text
openspot spot actions openspot/snooze
```

## Tell other spots what happened

A spot can also send news. Focus declares an event and sends it when a session ends.

`focus.spot/spot.toml`:

```toml
title = "Focus"
icon = "timer"

[actions.finish]
title = "Finish Focus"

[events.finished]
minutes = { type = "number", required = true }
```

`focus.spot/focus.sh`:

```sh
#!/bin/sh
case "$1" in
  finish) openspot emit finished minutes=25 ;;
esac
```

A spot that listens binds Focus and names the event in `[on]` as `<binding>.<event>`.

`streak.spot/spot.toml`:

```toml
title = "Streak"
icon = "flame"

[bindings]
focus = { spot = "focus" }

[on]
"focus.finished" = true
```

`streak.spot/streak.sh`:

```sh
#!/bin/sh
case "$1" in
  focus.finished) openspot toast "Nice: $(sed -n 's/^input.minutes=//p') minutes of focus" ;;
esac
```

Type `finish` in the panel, and press Return on Finish Focus. A message says Nice: 25 minutes of focus.

`openspot emit` checks each value against `[events.finished]`, and exits 2 on a wrong one. Openspot runs
`streak.sh focus.finished` with `input.minutes=25`, whether or not the panel shows.

## Next

- [Use the Mac: clipboard, screen, timers](the-mac.md)
- [spot.toml](../reference/spot-toml.md)
