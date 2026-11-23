# Frames

A frame is everything that a call shows at one time: the blocks it prints up to a line `---` or its end.

```ini
frame=
title=Ports
detail=2 listening

item=4120
title=:3000
detail=node

item=812
title=:5432
detail=postgres
---
```

- Openspot draws each frame as soon as it arrives.
- The first frame of a call replaces what shows, and so does a later frame with a `frame=` line.
- A later frame with no `frame=` line changes only the blocks it prints: a block with the id of one that shows changes
  only the keys it prints, and a block with a new id joins the end.
- If a `show` prints nothing, the spot shows nothing. What another call that prints nothing does is in
  [The calls](03-calls.md).

## The root

The root is the block of the frame's own keys. It starts with `frame=` or `error=`, and isn't drawn.

| Key        | Type           | Is                                                            |
| ---------- | -------------- | ------------------------------------------------------------- |
| `frame`    | text           | The route of the sheet that the frame is for, often empty.    |
| `title`    | text           | The title of the card.                                        |
| `detail`   | text           | The line under the card's title.                              |
| `class`    | classes        | The [layout](10-layout.md) of the frame's blocks.             |
| `value`    | id             | The block that is the spot's value on a card and in the menu bar. |
| `active`   | bool           | Whether the spot's thing is on, which its card shows.         |
| `recents`  | bool           | Whether the items pressed last come first, `true` by default. |
| `progress` | number, 0 to 1 | How much of the call's work is done.                          |
| `type`     | text           | `form`, which makes the frame a [form](07-actions-and-settings.md#forms). |
| `error`    | text           | The message of a failure of the call.                         |
| `call`     | number         | The call of a staying spot that the lines after it answer.    |
| `end`      | number         | The end of the answer of a call of a staying spot.            |

- `out.<name>=<value>` gives a value of an action's `outputs`, once for each value.
- `call` and `end` are for a program that serves calls itself; see [A staying spot](12-modes.md#a-staying-spot).

## Blocks

A block is one thing that a frame shows. Its first line is its kind and its id, such as `switch=vpn`, and it ends at a
blank line.

```ini
switch=vpn
title=VPN
value=true

button=forget
title=Forget
```

| Kind      | Is                                                              |
| --------- | --------------------------------------------------------------- |
| `item`    | A row of the list; see [Items](06-items.md).                    |
| `items`   | The list that the person searches and presses.                  |
| `text`    | Words.                                                          |
| `number`  | One value, as text, a ring or a bar.                            |
| `series`  | Points over time, as a bar for each.                            |
| `icon`    | An icon alone.                                                  |
| `picture` | An image that fills its area.                                   |
| `button`  | A button, or a row of the ⌘K menu.                              |
| `field`   | A text field, a slider or a key recorder.                       |
| `switch`  | A switch.                                                       |
| `choice`  | A menu of the `option` blocks after it.                         |
| `option`  | One option of the `choice` before it.                           |
| `box`     | A box that lays out the blocks inside it.                       |
| A view    | What a SwiftUI file of the spot draws; see [Views](14-views.md). |

[Blocks by kind](05-blocks.md) gives the keys of each kind. These keys work on every block:

| Key      | Type    | Is                                                         |
| -------- | ------- | ---------------------------------------------------------- |
| `title`  | text    | The first line of the block's words.                       |
| `detail` | text    | The line under the title.                                  |
| `icon`   | text    | An SF Symbol, an emoji, an image file or a web image.        |
| `tone`   | text    | The colour of the words: `good`, `warn` or `bad`.          |
| `parent` | id      | The block that this block sits inside.                     |
| `class`  | classes | The [classes](10-layout.md#classes) that place and style it. |
| `grow`   | bool    | Whether the block takes the free height of its box.        |

- The id names the block in the layout, and the handler that it calls.
- A frame with no [layout](10-layout.md) is a list: each block is a row, a `button` is a row of the ⌘K menu, and a
  `choice` shows over the list.
- `openspot check spots` reports an unknown key, kind or class, and Openspot skips it.
