# Bindings and events

A binding names another spot that your spot runs or listens to, and an event is news that your spot sends to the spots
that bind it.

```toml
[bindings]
picker = { spot = "openspot/snooze" }
```

```text
$ openspot run picker.pick title="Remind me later" --out until
2026-11-24T09:00:00+01:00
```

The tiles of Snooze, one of Openspot's own spots, show over your sheet. When the person picks one, the command prints
the time and ends. Its `pick` takes an optional `title` and gives `until`, a time that `openspot timer add` takes.

## [bindings]

| Key      | Type  | Is                                          |
| -------- | ----- | ------------------------------------------- |
| `<name>` | table | One spot that this spot binds, by a name of your choice. |
| `spot`   | text  | The id of the bound spot, required.         |

- Openspot's own spots have ids such as `openspot/snooze`. Any other spot's id is its folder's name.
- The person approves each binding when they add the spot.
- `openspot spot actions <id>` prints the actions of a spot that you can bind, with their inputs and outputs.
- `"<name>.<event>" = true` in `[on]` listens to an event of the bound spot.

## openspot run

`openspot run <binding>.<action> [<name>=<value>...] [--out <name>] [--stdin <name>]` runs an action of a bound spot,
and waits for its values.

- It prints the values as `out.<name>=` lines, or with `--out <name>` each value of that output on its own line.
- `--stdin <name>` reads that input from stdin, for a long value.
- An action that answers with a view shows it over your sheet, and the run ends at the bound spot's first frame with
  `out.` lines or `error=`.
- When the person closes that view, it exits 4. End the call with exit 0 then, so no failure shows, as
  [Use another spot](../../GUIDE.md#use-another-spot) does.
- It exits 2 for an unknown binding, action or input, or a wrong type, and 1 when the bound spot fails.
- A call that the person didn't press, such as `show` or a timer, can run an action, but not one that shows a view.

## [events.<name>]

`[events.<name>]` declares one event of the spot, with a type for each of its values.

```toml
title = "Focus"
icon = "timer"

[actions.finish]
title = "Finish Focus"

[events.finished]
minutes = { type = "number", required = true }
```

```sh
#!/bin/sh
case "$1" in
  finish) openspot emit finished minutes=25 ;;
esac
```

A spot that binds Focus as `focus = { spot = "focus" }` and has `"focus.finished" = true` in its `[on]` gets a call of
`focus.finished` with `input.minutes=25`.

- `<name>` MUST hold no dot.
- Each value takes a [type](02-spot-toml.md#types), or the table of an [input](02-spot-toml.md#an-input).

## openspot emit

`openspot emit <event> [<name>=<value>...]` sends one of the spot's events to each spot that binds it and listens to it.

- It checks the values as `openspot run` checks inputs, and exits 2 on a wrong one.
- Each spot that listens gets one call, whether or not the panel shows.
