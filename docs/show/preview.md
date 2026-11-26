# Show a preview of a row

You'll build Swatches, a list of colours whose preview shows each colour large. Space on a row shows its preview
beside the sheet, and Space or Esc hides it again.

## Let Openspot draw it

A row that carries its value shows a preview with no work from your spot. `text=` shows the whole text, `url=` the
link and its host, and `file=` the picture, or the file's icon and name. `whole=` names a file that holds the whole
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

Open Swatches, and press Space. The preview shows `#ff3b30` in large type.

## How it works

- With `"item.preview"` in its `[on]`, Openspot runs `item.preview` for the row that Space shows, with the row as
  `input.item=` and each of its keys as `input.item.<key>=`, such as `input.item.text=`.
- It takes `text`, `number`, `series`, `picture` and `icon` blocks, and a first block of the frame's own keys, such as
  `class`. A class with the `preview:` prefix applies only there.
- Openspot draws its own preview until yours comes, and keeps yours for the row, so a second look runs nothing.
- A preview takes up to two fifths of the screen's width, and is as tall as the sheet.

## Next

- [Lay out a sheet](a-layout.md)
