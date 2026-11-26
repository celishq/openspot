# Show a preview of a row

You'll build Swatches, a list of colours whose preview shows each colour large. `⌘Y` on a row shows its preview
beside the sheet, as Quick Look does in Finder, and `⌘Y` or Esc hides it again.

## Let Openspot draw it

A row that carries its value shows a preview with no work from your spot. `text=` shows the text, `url=` the link
and its host, `file=` the picture, filling the preview, or the file's thumbnail, and an `icon=#rrggbb` the colour. `whole=` names a file that holds the whole
text of a long row. The row's `detail` shows under it.

## Draw your own

`swatches.spot/spot.toml`:

```toml
title = "Swatches"
icon = "paintpalette"

[on]
"sheet.open" = true
"item.preview" = true
```

`swatches.spot/swatches.sh`:

```sh
#!/bin/sh
case "$1" in
  item.preview)
    hex=$(sed -n 's/^input.item.text=//p')
    printf 'frame=\nclass=flex-col gap-part\n\ntext=hex\ntitle=%s\nclass=font-title\n' "$hex"
    ;;
  *)
    printf 'item=red\ntitle=Red\ntext=#ff3b30\n\nitem=blue\ntitle=Blue\ntext=#007aff\n'
    ;;
esac
```

Open Swatches, and press `⌘Y`. The preview shows `#ff3b30` in large type.

## How it works

- With `"item.preview"` in its `[on]`, Openspot runs `item.preview` for the row that `⌘Y` shows, with the row as
  `input.item=` and each of its keys as `input.item.<key>=`, such as `input.item.text=`.
- It takes `text`, `number`, `series`, `picture` and `icon` blocks, and a first block of the frame's own keys, such as
  `class`. A class with the `preview:` prefix applies only there.
- Openspot draws its own preview until yours comes, and keeps yours for the row, so a second look runs nothing.
- A preview is 340 points wide and up to 380 tall, beside the sheet, with the row's title and `detail` under it.

## Give a type

A spot that knows a kind of value draws the preview of each row that holds one, in any sheet, and adds its actions to
the row's `⌘K` menu. The Colors spot that comes with Openspot does this for colours:

```text
[types.color]
title = "Color"
match = '^#[0-9a-fA-F]{6}$'

[actions.copy-rgba]
title = "Copy as RGBA"
type = "color"
```

A copied `#ff3b30` then shows in the Timeline sheet with its colour, and `⌘K` on it offers Copy as RGBA. The sheet's
own spot draws the preview when it answers `item.preview` itself. [spot.toml](../reference/spot-toml.md#typesname) lists
the keys.

## Next

- [Lay out a sheet](a-layout.md)
