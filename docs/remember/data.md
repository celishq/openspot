# Keep your own data

You'll build Water, which counts the glasses you drink today. Press the row to add one. The count lasts through a
restart and an update of the spot, and starts again each day.

## Make the spot

`water.spot/spot.toml`:

```toml
title = "Water"
icon = "drop"
```

`water.spot/water.sh`:

```sh
#!/bin/sh
file="$OPENSPOT_DATA/glasses"
today=$(date +%F)
count=$(sed -n "s/^$today=//p" "$file" 2>/dev/null)
count=${count:-0}
case "$1" in
  show) printf 'item=drink\ntitle=Glasses today: %s\ndetail=Press to add one\nclose=false\n' "$count" ;;
  press)
    printf '%s=%s\n' "$today" "$((count + 1))" > "$file.new"
    mv "$file.new" "$file"
    ;;
esac
```

Open Water. It shows Glasses today: 0. Press the row, and it shows Glasses today: 1.

## How it works

`OPENSPOT_DATA` is your spot's own folder, `~/.config/openspot/data/water`. Openspot makes it before the first run.
Keep anything that lasts there.

`close=false` keeps the panel open after a press. Openspot then runs `water.sh show` again, so the new count shows.

## Write the whole file

Openspot can stop a run at any moment, such as when people press again or quit. A stop in the middle of a write
leaves half a file. So write a new file beside the old one, then move it into place, as `press` does. A move is
whole or not at all.

If you load the shell helper, `openspot_keep` does the same in one line:

```text
. "$OPENSPOT_SH"
openspot_keep "$OPENSPOT_DATA/glasses" "$(date +%F)=1"
```

It writes its second argument, or stdin, to the file.

## What lasts

The data folder sits outside your spot's folder. An update of the spot changes the files of its folder and leaves
the data alone. Removing the spot keeps the data too.

Don't keep data in the spot's own folder, since an update can replace it.

In Careful mode, a setting people can turn on, your spot can write only to its data folder and the temp folders. Add
`files` to `uses` in `spot.toml` to write anywhere else. People see that use when they add your spot.

## Next

- [Settings people choose](settings.md), for a choice people make
- [Use the Mac](../connect/the-mac.md)
