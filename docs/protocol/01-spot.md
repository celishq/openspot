# A spot

A spot is a folder with a `spot.toml` and a script, and Openspot runs the script to fill a sheet of its panel.

```text
ports.spot/
  spot.toml
  ports.sh
```

`spot.toml` names the spot:

```toml
title = "Ports"
icon = "network"
```

`ports.sh` lists each process that listens on a port, and stops the one you press:

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

Put the folder in `~/.config/openspot/spots` and run `chmod +x ports.sh`. Openspot loads it a moment later.

## The folder

| File             | Required | Is                                                                     |
| ---------------- | -------- | ---------------------------------------------------------------------- |
| `spot.toml`      | yes      | What the spot has; see [spot.toml](02-spot-toml.md).                   |
| `<name>.<ext>`   | yes      | The script, named like the folder, such as `ports.sh` or `ports.js`.   |
| `readme.md`      | no       | The page that the Store shows about the spot.                          |
| `sample.sh`      | no       | A script that prints what the spot shows, with made-up data.           |
| `releases.jsonl` | no       | The signed releases; see [Signed releases](../../TRUST.md#signed-releases). |

- The id of a spot is the name of its folder without `.spot`, such as `ports`.
- A spot folder must hold 25 MB or less.

## A call

Each time Openspot needs the spot, it runs the script once. That run is a call. Its first argument is the handler, the
part of the script that answers, and stdin holds its inputs:

```text
ports.sh press
```

```ini
input.item=4120
```

[The calls](03-calls.md) lists each handler and what it gets.

## A frame

The script answers on stdout with a frame, the lines that say what to show. A frame is blocks of `key=value` lines, and
a blank line ends each block:

```ini
item=4120
title=:3000
detail=node

item=812
title=:5432
detail=postgres
```

`item=4120` starts an item, a row of the list with the id `4120`. A frame of items shows as a list that the person
searches, and a press of a row calls `press` with its id.

- A line splits at its first `=`.
- In a value, `\n` is a new line and `\\` is a backslash. An empty value is no value.
- A line `---` ends a frame, so one call can print several frames, such as one at each step of its work.
- A value that comes from data MUST be printed with `openspot_item`, `openspot_kv` or `esc`, so that it can't add a line
  or a block.

[Frames](04-frames.md) says how a frame changes what shows.
