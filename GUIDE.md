# Openspot guide

In this guide, you build spots, the small programs that Openspot shows in its panel. Each task is one working spot. The
[protocol](PROTOCOL.md) holds every rule, and [Use Openspot](USING.md) says what the person who uses your spot chooses.

## Build your first spot

Build a spot when you want a small tool one key away. This one lists each process that listens on a port, and stops the
one you press, such as a server that's still on :3000.

A spot is a folder in `~/.config/openspot/spots`. Make the folder `ports.spot`, and save the file that names the spot as
`ports.spot/spot.toml`:

```toml
title = "Ports"
icon = "network"
```

Save its script beside it, named like the folder, as `ports.spot/ports.sh`:

```sh
#!/bin/sh
. "$OPENSPOT_SH"
case "$1" in
  show)
    lsof -nP -iTCP -sTCP:LISTEN | awk 'NR > 1 && !seen[$2]++ {
      sub(/.*:/, ":", $9)
      print $2 "\t" $9 "\t" $1
    }' | openspot_items
    ;;
  press) kill "$(value item)" ;;
esac
```

<!-- draw: lsof() { printf 'COMMAND PID USER FD TYPE DEVICE SIZE NODE NAME\nnode 4120 me 21u IPv4 0x1 0t0 TCP *:3000 (LISTEN)\npostgres 812 me 7u IPv4 0x2 0t0 TCP 127.0.0.1:5432 (LISTEN)\npython3 5051 me 3u IPv6 0x3 0t0 TCP *:8080 (LISTEN)\n'; }; . "$EXAMPLE" -->
![The sheet of Ports: a row for each process that listens, such as :3000 with node under it](docs/images/first-spot.png)
The sheet of Ports lists a row for each process that listens, with its port as the title and its name under it.

1. Run `chmod +x ports.sh` in the spot folder. Openspot loads the spot, and its card shows in the panel.
2. Press `⌃Space`, then press the Ports card. Its sheet opens with a row for each port.
3. Press Return on a row. The process stops, and the panel closes.

Each run of your script is a call. Its first argument names the handler, the part of the script that answers: `show`
asks what to show, and `press` says that the person pressed a row. `. "$OPENSPOT_SH"` loads the shell helper, which
gives you `value item`, the id of the pressed row, and `openspot_items`, which turns each line of id, title and detail,
split by tabs, into a row. What `show` prints is a frame:

```text
item=4120
title=:3000
detail=node

item=812
title=:5432
detail=postgres
```

### Try your spot

Run one call of the spot, the way Openspot calls it, and see what it prints:

```sh
openspot spot run ports show
openspot check spots ~/.config/openspot/spots
openspot spot log ports
```

`spot run` prints the frame above. `check spots` prints nothing when each spot loads and runs, or a `fault` block for
each error. `spot log` prints the last calls, with their stdin, stdout, stderr and exit code.
`openspot playground open ports.spot/ports.sh` shows the spot in a panel of its own, and runs it again at each save.

Learn more in [A spot](docs/protocol/01-spot.md), [The calls](docs/protocol/03-calls.md) and
[Items](docs/protocol/06-items.md).

## Add an action

Add an action when your spot does a thing that the person runs by name, such as moving a window. A table
`[actions.<id>]` declares it, and a run calls the handler of its id.

`windows.spot/spot.toml`:

```toml
title = "Windows"
icon = "macwindow"
uses = ["screen"]

[actions.full]
title = "Full screen"
icon = "rectangle.inset.filled"

[actions.left]
title = "Left side"
icon = "rectangle.lefthalf.inset.filled"
```

`windows.spot/windows.sh`:

```sh
#!/bin/sh
case "$1" in
  full) openspot window move "0 0 1 1" ;;
  left) openspot window move "0 0 1/2 1" ;;
esac
```

1. Type `left` in the panel. The search lists Left side, with its icon.
2. Press Return on it. Openspot runs `windows.sh left`, and the front window fills the left half of the screen.
3. Press `⌘` Return on the Windows card. Its Settings list a key for each action, which the person records.

`uses` names the features of the Mac that the spot uses, here `screen` for `openspot window move`. A spot whose actions
have titles, and that has no `[on]`, has no sheet, so a press of its card runs its first action.

Learn more in [Actions and settings](docs/protocol/07-actions-and-settings.md) and
[The openspot command](docs/protocol/15-commands.md).

## React to an event

React to an event when your spot shows something that changes, such as the free space of the disk. The `[on]` table
lists the triggers, the things that call a spot by themselves.

`disk.spot/spot.toml`:

```toml
title = "Disk"
icon = "internaldrive"

[on]
"panel.open" = true
every = 300
```

`disk.spot/disk.sh`:

```sh
#!/bin/sh
free=$(df -h / | awk 'NR==2 {print $4}')
printf 'frame=\ndetail=%s free\n\nitem=free\ntitle=%s free\n' "$free" "$free"
```

<!-- card: wide -->
<!-- draw: df() { printf 'Filesystem Size Used Avail\n/dev/disk 994Gi 738Gi 256Gi\n'; }; . "$EXAMPLE" -->
![The card of Disk, with the free space under its title](docs/images/show-a-value.png)

The wide card of Disk shows its icon, the title Disk with 256Gi free under it, and an arrow at its end.

1. Add Disk to the grid in Edit Spots, since a spot with `every` starts off the grid.
2. Free some space, and open the panel again. The card shows the new value.

`"panel.open" = true` calls `show` each time the panel opens, and `every = 300` calls `every` every 5 minutes while the
card shows. The first block, `frame=`, holds the frame's own keys, and its `detail` is the line under the card's title.

Learn more in [Triggers](docs/protocol/08-triggers.md), [The root](docs/protocol/04-frames.md#the-root) and
[Places](docs/protocol/11-places.md).

## Use another spot

Use another spot when a step of yours is the job of another spot, such as picking a time. A binding names the other
spot, and your spot runs its action and waits for its values.

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
. "$OPENSPOT_SH"
case "$1" in
  show) printf 'button=later\ntitle=Remind me later\nscope=spot\n' ;;
  later)
    picked=$(openspot run picker.pick title="Remind me later" --out until)
    case $? in 0) ;; 4) exit 0 ;; *) exit 1 ;; esac
    openspot timer add "$picked" remind words="Look at this again"
    ;;
  remind) openspot toast "$(value words)" ;;
esac
```

1. Choose Remind me later in the ⌘K menu. The tiles of Snooze, a spot of Openspot, show over the sheet.
2. Pick Tomorrow. `openspot run` prints the time, and the spot adds a timer that calls `remind` then.
3. Press Esc instead. `openspot run` exits 4, and the call ends with no failure.

`openspot spot actions openspot/snooze` prints the actions that you can run, with their inputs and outputs. `pick` takes
an optional `title` and gives `until`, a time that `openspot timer add` takes.

Learn more in [Bindings and events](docs/protocol/09-bindings-and-events.md) and
[openspot timer](docs/protocol/15-commands.md#openspot-timer).

## Lay out a sheet

Lay out a sheet when a list isn't enough, such as a row of an icon, words and a button. A `box` block holds the blocks
whose `parent` names it, and its classes, the words of Tailwind CSS, say how it lays them out.

`wi-fi.spot/spot.toml`:

```toml
title = "Wi-Fi"
icon = "wifi"
```

`wi-fi.spot/wi-fi.sh`:

```sh
#!/bin/sh
printf 'frame=\nclass=gap-part\n\nbox=head\nclass=flex-row items-center gap-2\n\n'
printf 'icon=wifi\nparent=head\nvalue=wifi\nclass=text-accent\n\n'
printf 'text=name\nparent=head\ntitle=Home\ndetail=82 Mb/s\nclass=grow\n\n'
printf 'button=forget\nparent=head\ntitle=Forget\nclass=rounded-full\n'
```
![The sheet: one row, the Wi-Fi icon, Home with 82 Mb/s under it, and a Forget chip](docs/images/lay-out-a-sheet.png)

The sheet shows one row: the Wi-Fi icon in the accent colour, Home with 82 Mb/s under it, and a Forget chip at its end.

1. Remove `class=grow` from the `text` block. The chip moves next to the words, since no block takes the free width.
2. Press Forget. Openspot runs `wi-fi.sh forget`.

Learn more in [Layouts](docs/protocol/10-layout.md) and [Blocks by kind](docs/protocol/05-blocks.md).
