# Use the Mac: clipboard, screen, timers

You'll build Dates, a list of today's date in three forms. Press one, and it's on your clipboard.

## Make the spot

`dates.spot/spot.toml`:

```toml
title = "Dates"
icon = "calendar"
uses = ["clipboard"]
```

`dates.spot/dates.sh`:

```sh
#!/bin/sh
case "$1" in
  show)
    for format in %F '%d %b %Y' %d/%m/%Y; do
      printf 'item=%s\ntitle=%s\n\n' "$(date "+$format")" "$(date "+$format")"
    done
    ;;
  press)
    date=$(sed -n 's/^input.item=//p')
    printf %s "$date" | openspot clipboard copy
    openspot toast "Copied $date"
    ;;
esac
```

Open Dates. It lists 2026-11-23, 23 Nov 2026 and 23/11/2026. Press one, and a message says Copied 2026-11-23.

## How it works

Your spot asks the Mac for things with the `openspot` command. It's on the `PATH` of every run, and it works the same
in a terminal, so you can try each call by hand.

`uses` names what your spot needs from the Mac. People see the list when they add your spot, before it runs. Name
each use your commands need. A command whose use is missing still runs, and people see a message about it once a day.

Careful mode is a setting people can turn on in Openspot's Settings. It runs each spot in a sandbox, and there a
command whose use is missing fails. [Careful mode](../../TRUST.md#careful-mode) says what else it stops.

`show` only shows. Commands that change the Mac, such as `clipboard copy`, work in `press` and in your actions, and
fail in `show`. `toast` works anywhere.

## What you can ask

| Command                                     | Does                                                      | `uses`      |
| ------------------------------------------- | --------------------------------------------------------- | ----------- |
| `openspot clipboard copy`, `paste`, `read`  | Copies stdin or a file, pastes into the front app, reads text. | `clipboard` |
| `openspot toast <words>`, `--remove <id>`   | Shows a short message, even when the panel is closed, or takes it away. [A toast](../reference/commands.md#a-toast) has its options. | none        |
| `openspot window frame`, `move <frame>`     | Reads or moves the front window.                          | `screen`    |
| `openspot screen shot`, `record start`      | Takes a picture or a recording of the screen.             | `screen`    |
| `openspot color pick`, `folder pick`        | Asks people to pick a colour or a folder.                 | `screen`, none |
| `openspot timer add <time> <action>`        | Runs an action of your spot at a time.                    | `timer`     |
| `openspot calendar`, `reminders`            | Reads and adds events and reminders.                      | `calendar`  |
| `openspot power lid-closed`                 | Keeps the Mac awake with its lid closed.                  | `power`     |

Two uses have no command, and they count only in Careful mode. Without `network`, your spot can't reach the network
there, and without `files`, it can write only to its [data folder](../remember/data.md) and the temp folders.

`openspot help <noun>` prints every verb of a noun, such as `openspot help screen`.

## Next

- [Use another spot](other-spots.md)
- [The openspot command](../reference/commands.md)
