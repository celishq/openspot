# Keep a timeline

You'll build Moods, which keeps how you feel through the day. Press a row to add a mood. Openspot keeps each one with
its time in the timeline, and the sheet lists the last five.

## Make the spot

`moods.spot/spot.toml`:

```toml
title = "Moods"
icon = "face.smiling"
uses = ["timeline"]
```

`moods.spot/moods.sh`:

```sh
#!/bin/sh
case "$1" in
  show)
    printf 'item=good\ntitle=Good\nclose=false\n\nitem=tired\ntitle=Tired\nclose=false\n\n'
    openspot timeline list --limit 5 | sed 's/^item=/item=past-/'
    ;;
  press)
    mood=$(sed -n 's/^input.item=//p')
    case "$mood" in past-*) exit 0 ;; esac
    openspot timeline add text="$mood" key="$(date +%F)-$mood" >/dev/null
    ;;
esac
```

Open Moods and press Good. A row, Good, shows under the two moods. Press Good again, and the row moves to the top
instead of showing twice.

## How it works

`openspot timeline add` keeps one entry and prints its id. It takes one value: `text=`, `url=` or `file=`
once for each file. With `title=`, `detail=`, the line under the title, `app=`, the bundle ID of the app it came from, and `icon=` it says how the entry
shows. With no words, it takes the same lines on stdin, and adds nothing when they hold no value.

`key=` names the entry. An add with the key of an entry the spot kept moves that entry to the top with the new value.

`at=` sets the time, as ISO 8601, such as `2026-11-20T08:00:00+01:00`, for an entry of the past. Without it, the entry
takes the time of the add.

`openspot timeline list` prints your spot's entries, newest first, each as an item with its `kind`, `text`, `url` or `file`:

```ini
item=3f9a2c1b
title=good
spot=moods
at=2026-11-26T10:12:40+01:00
kind=text
text=good
key=2026-11-26-good
```

`--within 1d` keeps the entries of the last day, `--text cafe` the ones that hold each word, and `--limit 5` the first
five. A text of more than 16 KB prints its first 16 KB in `text=`, and the whole text sits in the file of
`text.file=`.

## What lasts

Openspot keeps each entry for 30 days, then drops it with its day. A file of up to 25 MB on the disk of
your home folder is kept as a copy, so the entry keeps it after people delete the file. `file=` of such an entry names
the copy. A larger file, a folder, or a file on another disk, keeps only its path.

The timeline also stays within 2 GB in all. Past that, its oldest entries go first.

`openspot timeline forget <id>` takes an entry out. `openspot timeline restore <id>` brings it back within 10 minutes,
and after that it's gone.

## Keep what happens while the panel is closed

A spot with `timeline` in its `uses` gets the events of its `[on]` at all times, not only while it shows. The
Clipboard spot that comes with Openspot keeps each copy this way:

```text
clipboard.change) openspot clipboard read --blocks | openspot timeline add >/dev/null ;;
```

## Read another timeline

A spot reads only its own timeline. `--spot clipboard` reads the timeline of the spot `clipboard`, and `--all` reads
every timeline. Both need `read` in `uses`, since a timeline holds what people did.

When a spot that read a timeline has its sheet open, an add to that timeline runs its `show` again, so the new entry
shows.

## Next

- [Keep your own data](data.md)
- [Answer when the Mac changes](../react/mac-events.md)
