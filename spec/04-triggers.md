# 04 Triggers

`final` · Needs 01.

Two header keys start a call from outside the panel's search: `drop` for files, and `command` for a key in any app.

## Drops

Add `drop` to the header, and the card takes files.

```sh
#!/bin/sh
# name=To MP4
# symbol=film
# drop=mov,mkv,avi,webm
case "$1" in
  drop)
    shift
    for file; do
      ffmpeg -y -i "$file" "${file%.*}.mp4" >/dev/null 2>&1 || exit 1
    done
    printf 'toast=Done\n'
    ;;
esac
```

| `drop` holds | The card takes |
|---|---|
| An extension, such as `mov` | A file with this extension, in upper or lower case. |
| `folder` | A folder. A bundle, such as an app, is a folder. |
| `*` | Each file and each folder. |

- To drop files, drag them over the Openspot item in the menu bar. The panel opens and the focus stays where it is. The panel stays open until the drag ends.
- A card takes a drag only when its `drop` takes each dragged file. For the whole drag, each such card changes its fill, and the card under the drag fills fully, because it takes the drop. Other cards do not change. A mix with one other file goes to no card.
- A drop runs one call, `drop <path> [path]...`, and closes the panel. Each full path is its own argument, so write `"$file"` with its quotes.
- A drop on a card with a running call waits, and runs when that call ends. It does not stop the call. A `read` does not hold a drop.
- A click on a card with `drop` and no sheet opens a file chooser, and the choice runs the same call. A toggle and a slider keep their own click, and a card with a sheet opens its sheet.
- A `drop` call runs as any other call does. It has no time limit, and it goes on with the panel closed. A second press of its card stops it.

## Commands with keys

A script lists what it can do, and the person chooses the keys. A script never holds a key.

```sh
#!/bin/sh
# name=Music
# command=pause:Play or pause
case "$1" in
  pause) osascript -e 'tell application "Music" to playpause' ;;
esac
```

`command` holds an ID, a title and an optional SF Symbol, such as `command=left:Left side:rectangle.lefthalf.inset.filled`,
one line for each command. Without a symbol, its row shows the `symbol` of the script.

Settings shows one row for each command, and the person records a key there. A press in any app runs `<script> <id>` with no panel, and the script can print `toast=Done`. The file `config.toml` holds each key, and a person can also write it by hand:

```text
[[keys]]
spot = "music"
command = "pause"
key = "ctrl+option+p"
```

- A script with commands and no `read` opens to the rows of its own commands, where the person records keys as in Settings.
- A key holds cmd, ctrl or option, with a letter, a digit, an arrow, space, return or tab.
- Presses run one at a time and in order. A press never stops a call, so keep the call short.
- A key that macOS refuses shows a toast. A hand edit takes effect when the panel next opens.
- A key works with the panel open too, so the front app can be Openspot.

## Rules

| ID | Rule |
|---|---|
| D1 | A drag over the Openspot item in the menu bar opens the panel with no change of focus, until the drag ends. |
| D2 | During a drag, each card whose `drop` takes every dragged file shows it, and only such a card takes the drop. |
| D3 | A drop is one `drop` call, with each path as its own argument, and it closes the panel. |
| D4 | A drop on a card with a running call waits for that call. It does not stop it. |
| D5 | A click on a card with `drop` and no sheet opens a file chooser, and the choice runs the same call. |
| D6 | A `drop` call runs as any other call does. |
| C7 | Presses of the keys of one script run one at a time and in order. A press of a key never stops a call. |
| P8 | Only a command that a header lists can have a key, and only the person assigns it. |

## Why not

| Decision | Why | Rejected |
|---|---|---|
| A script lists commands, and the person gives them keys | A key depends on the person's hands and apps, and the config holds each key in one place. | A `global` key in the header. |
