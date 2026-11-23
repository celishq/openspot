# Lists and pages

`draft` `optional` · Builds on [01](01-spot.md)

Use this when your spot shows a list that people search and act on, such as files, tabs or tasks, or when a row opens
a sheet of its own.

```toml
title = "Downloads"
```

```sh
#!/bin/sh
. "$OPENSPOT_SH"
case "$1" in
  show)
    openspot_item report Report.pdf
    openspot_kv path "$HOME/Downloads/Report.pdf"
    printf '\nbutton=reveal\ntitle=Show in Finder\nshortcut=cmd+o\n'
    ;;
  reveal) open -R "$(value item.path)" ;;
esac
```

The sheet shows one row, Report.pdf. `⌘O`, or Show in Finder in its ⌘K menu, calls `reveal` with `input.item=report`
and `input.item.path=` the path.

## Items

An item is a row of the list. A press calls `press` with its id as `item`, and a [button](03-blocks.md#buttons) in the
frame acts on the selected item.

| Key             | Type | Is                                                                        |
| --------------- | ---- | ------------------------------------------------------------------------- |
| `title`         | text | The first line of the row, the id by default.                             |
| `detail`        | text | The line under the title.                                                 |
| `icon`          | text | The icon of the row.                                                      |
| `tone`          | text | A dot of its colour on the icon.                                          |
| `value`         | bool | Whether the row shows a checkmark.                                        |
| `keywords`      | text | Words that find the item but don't show, split by commas.                 |
| `place`         | text | Where the item sits in its spot, which the panel's search shows.          |
| `pin`           | text | The edge that the item stays at while the rest scroll: `top` or `bottom`. |
| `hides`         | id   | A button of the ⌘K menu that the item doesn't offer, one line each.       |
| `file`          | path | The file that the item stands for, which the person can drag out.         |
| `close`         | bool | Whether the panel closes after a press of the item.                       |
| `shake`         | bool | Whether a shake can be the key that the item records.                     |
| `open.title`    | text | The words of Return on this item.                                         |
| `route`         | text | The route that a press opens; see [Pages](#pages).                        |
| `route.title`   | text | The title of the route's sheet, the item's title by default.              |
| `route.replace` | bool | Whether the route's sheet replaces the one that shows.                    |

- Any other key, such as `path=`, is the item's own, and comes back as `input.item.<key>=`.
- The items that the person pressed last come first. `recents=false` in the [root](01-spot.md#the-root) keeps the
  order you print.
- When the person drags items that have a `file` out of the sheet, Openspot calls `<spot> drag` with `item` once for
  each item.

## The items block

`items=<id>` is the list itself, the block that the person searches and presses. You need it once your frame has a
[layout](04-layouts.md), so the list can sit beside other blocks.

```ini
frame=
class=gap-part

text=hint
title=Your files

items=files
class=grid grid-cols-4

item=report
parent=files
title=Report.pdf
```

- A frame holds one `items` block at most. In a frame with a layout, only the blocks whose `parent` is the `items`
  block are items. In a frame with no layout, every block is.
- `class=grid grid-cols-4` on the `items` block shows the items as tiles.
- Inside the `items` block, a `box` is a group, headed by its `title`.

## Pages

A page is a sheet of your spot that a route names, such as `photo/12`. An item with `route=` opens it.

```toml
title = "Fruit"
icon = "leaf"
pages = ["*"]
```

```sh
#!/bin/sh
. "$OPENSPOT_SH"
route=$(value route)
case "$route" in
  '') printf 'item=apple\ntitle=Apple\nroute=apple\n\nitem=pear\ntitle=Pear\nroute=pear\n' ;;
  *) openspot_item "$route:color" "Color" "Green" ;;
esac
```

Return on Apple opens its page, with one row, Color. `⌘[` goes back, and Esc takes the page off.

- `pages` in `spot.toml` lists the routes that the spot may show, where `*` stands for any text.
- A press of an item with a `route` opens it at once, with no call of `press`.
- Each call of the page's sheet gets the route as the input `route`, and the frame's `frame=` names it.
- `openspot route push <route>` shows a route over the sheet, `openspot route back` goes back one, and
  `openspot route close` takes each sheet of the spot off.
