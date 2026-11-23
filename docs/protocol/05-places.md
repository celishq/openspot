# Places

`draft` `optional` · Builds on [01](01-spot.md) and [04](04-layouts.md) · Uses [08](08-triggers.md)

Use this when your spot should show its value without being opened, such as the free space of a disk on its card or
in the menu bar, or answer in the panel's own search. A place is where a spot shows: its sheet, a card in the panel,
the menu bar, a float or a window.

```toml
title = "Disk"
icon = "internaldrive"

[on]
"panel.open" = true
every = 300
```

```sh
#!/bin/sh
free=$(df -h / | awk 'NR==2 {print $4}')
printf 'frame=\ndetail=%s free\n\nitem=free\ntitle=%s free\nclass=bar:flex\n' "$free" "$free"
```

The card shows Disk with the free space under it. When the person turns on Show in the menu bar, the menu bar shows the
item's title, such as 256Gi free, next to the clock.

One frame draws every place, and [variants](04-layouts.md#variants) such as `card:` and `bar:` lay out each one.

| Place                                       | Is                                                        |
| ------------------------------------------- | --------------------------------------------------------- |
| `small`, `wide`, `square`, `strip`, `large` | A card in the panel, of the size that the person chooses. |
| `bar`                                       | The menu bar, next to the clock.                          |

- The sheet fills the panel when the person opens the spot. A float, a small window at the pointer, and a window draw
  as the sheet does.
- The person chooses the places, as [Choose where a spot shows](../../USING.md#choose-where-a-spot-shows) says.

## The card

The card stands for your spot in the panel.

- With no class that names `card:` or a size, the card shows the spot's icon, and the `title` and `detail` of the
  frame's root, or else of `spot.toml`.
- Once a class names `card:` or a size, the card draws the frame's blocks, such as a `number` with
  `class=hidden card:flex`.
- When the card shows more than one `text`, `number`, `series`, `switch` or slider, `value=<id>` in the root names its
  value.
- `active=true` in the root says that the spot's thing is on, such as a timer that runs, and the card shows it.
- A press on a switch of the card flips it. Any other press does what Return does.

## The menu bar

The menu bar shows your spot's value small, beside the clock, once a class names `bar:`.

- It shows the first block with `bar:`, or the one that `value` in the root names.
- A `number` with `type=ring` is a small ring. A `series` is its last 8 bars. A `text` or `item` is its title, after a
  dot of its `tone`.
- With no `bar:` class, it shows the spot's icon, and a click opens the sheet under it.

## The main search

The main search is the panel's own search field, which lists items from every spot.

```toml
title = "Calculator"
icon = "equal.square"

[on]
search = "^[0-9(]"
```

```js
export default {
  search({ text }) {
    return openspot.call(["calc", "solve", text]).stdout
  },
}
```

Typing `2+2` in the panel shows a row, 4, at the top, in the same keystroke.

- `search = true` in `[on]` adds the items of the spot's `show` to the main search.
- `search = "<regex>"` calls `<spot> search` at each text that matches, with the text as `text`, and the texts the
  person may have meant, such as in another keyboard layout, as `alt`. A newer text stops the older call.
- `answers` in `spot.toml` says where the answers show: first by default, or under the others with
  `answers = "last"`. `answers = "card"` shows the card of the frame's value in their place.
