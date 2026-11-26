# Peek at a row

You'll build Swatches, a list of colours. Each row only names its colour, and `⌘P` shows the whole of it beside the
sheet, as Quick Look does in Finder. `⌘P` again or Esc hides it.

## Let Openspot draw it

A row that carries its value can be peeked with no work from your spot:

- `text=` shows the whole text.
- `url=` shows the link and its host.
- `file=` shows the picture, or the file's thumbnail. A `.mov`, `.mp4` or `.m4v` plays muted on a loop once the peek
  is open, and `⌘K` pauses it.
- `icon=#rrggbb` shows the colour.

The row's `title` and `detail` show under it.

## Print the peek with the row

A `peek` block whose `parent` is a row's id holds the peek of that row. The blocks whose `parent` is the peek draw in
it, and none of them is a part of the sheet.

`swatches.spot/spot.toml`:

```toml
title = "Swatches"
icon = "paintpalette"
uses = ["clipboard"]
```

`swatches.spot/swatches.sh`:

```sh
#!/bin/sh
case "$1" in
  show)
    printf 'item=red\ntitle=Red\ntext=#ff3b30\n\n'
    printf 'peek=red-peek\nparent=red\nclass=flex-col gap-part\n\n'
    printf 'icon=red-square\nparent=red-peek\nvalue=#ff3b30\n\n'
    printf 'text=red-hex\nparent=red-peek\ntitle=#FF3B30\nclass=font-title\n\n'
    printf 'button=red-rgb\nparent=red-peek\ntitle=Copy RGB\ncopy=rgb(255 59 48)\n\n'
    printf 'button=red-name\nparent=red-peek\ntitle=Rename\nrun=rename\n'
    ;;
  rename)
    openspot toast "Renamed $(sed -n 's/^input.item=//p')."
    ;;
esac
```

Open Swatches, and press `⌘P`. The peek shows the red square over `#FF3B30` in large type. `⌘K` on the row offers
Copy RGB and Rename.

## Give it actions

A `button` in a peek is an action of its row's `⌘K` menu. It does one of these:

| Key       | Does                                                                     |
| --------- | ------------------------------------------------------------------------ |
| `copy`    | Copies its text.                                                         |
| `paste`   | Copies its text and pastes it into the app in front.                     |
| `open`    | Opens its link, or the file at its path.                                 |
| `run`     | Runs your spot with that id, as a button of the sheet does, with the row. |

A button whose id starts with another button's id and a dot, such as `copy-as.hex` after `copy-as`, sits in that
button's submenu. A copied colour peeks this way with Copy as › HEX, RGB, RGBA, HSL and SwiftUI.

Openspot runs `copy`, `paste` and `open` itself, so your spot doesn't run. They still need the uses of your spot, such
as `clipboard`.

## How it works

- The peek is 340 points wide and up to 380 tall. Content that passes it is cut off.
- It takes `text`, `number`, `series`, `picture`, `icon` and `box` blocks. A class with the `peek:` prefix applies only
  there. A peek that holds none of them shows what Openspot draws.
- A `peek` block whose `parent` names no row is a fault of the frame.
- [Timeline](../remember/timeline.md#make-the-spot) keeps the peek that a spot gives with an entry.

## Next

- [Lay out a sheet](a-layout.md)
