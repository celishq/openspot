# Blocks by kind

`draft` `optional` · Builds on [01](01-spot.md)

Use this when a row of words isn't enough: when your spot shows a number, a chart or an image, or gives the person a
button, a field, a switch or a choice.

```ini
number=battery
title=Battery
value=84
max=100
unit=%
type=ring
```

Each kind of block takes the [keys of every block](01-spot.md#blocks), and the keys of its kind below. In a frame with
no [layout](04-layouts.md), each block is a row, a `button` is a row of the ⌘K menu, and a `choice` shows over the
list.

## Words and values

| Key | On | Is |
| --- | --- | --- |
| `value` | `text` | The words of a text that is the value on a card. |
| `color` | `text` | A `#RRGGBB` bar at the text's edge. |
| `value` | `icon` | The icon, in any form that `icon` takes. |
| `icon` | `picture` | The image, in any form that `icon` takes. |
| `value` | `number` | The number. |
| `max` | `number` | The value of a full ring or bar. |
| `unit` | `number` | The words after the value, as in `84%`. |
| `display` | `number` | The words that show in place of the value. |
| `type` | `number` | The look: `ring` or `bar`, or text when there is none. |
| `value` | `series` | The points, oldest first, split by commas, with `-` for a gap. |
| `add` | `series` | Points to put after the last. |
| `keep` | `series` | The most points that it holds, `60` by default and 600 at most. |
| `max`, `unit`, `display` | `series` | As on a `number`. |

A `text` is words, a `number` one value, a `series` points over time drawn as a bar each, an `icon` an icon alone, and
a `picture` an image that fills its area.

## Buttons

A `button` is a verb that the person presses, and a press calls the handler of its id.

```ini
button=rename
title=Rename
shortcut=cmd+r
```

| Key        | Is                                                                           |
| ---------- | ---------------------------------------------------------------------------- |
| `scope`    | Where it shows in the ⌘K menu: `item`, while an item is selected, or `spot`. |
| `shortcut` | The key that presses it, such as `cmd+r`, `cmd+shift+return` or `escape`.    |
| `confirm`  | The words that ask the person to press a second time.                        |
| `close`    | Whether the panel closes after a press that answers with no view.            |

- A press calls `<spot> <id>`, which needs no action in `spot.toml`. Declare an [action](06-actions.md) to type its
  inputs.
- A button with a `scope`, inside the `items` block, or in a frame with no layout is a row of the ⌘K menu, and gets the
  selected item as the input `item`. Any other button draws where the layout puts it.
- With `confirm`, the first press shows the words, and the second press calls the handler.
- `button=press` names Return: its `title` shows in the ⌘K menu and the footer.

## Inputs

A `field`, a `switch` and a `choice` call the handler of their id with their new value as `value`. A `choice` is a menu
of the `option` blocks after it.

```ini
field=name
title=Name
placeholder=Your name

choice=units
value=c

option=c
title=Celsius

option=f
title=Fahrenheit
```

| Key | On | Is |
| --- | --- | --- |
| `value` | `field` | The text of the field. |
| `type` | `field` | The kind of input: `multiline`, `slider`, `search` or `hotkey`. |
| `placeholder` | `field` | The words that show while the field is empty. |
| `required` | `field` | Whether a form needs a value in the field. |
| `readonly` | `field` | Whether the person can't change the field. |
| `min`, `max` | `field` | The range of a slider, `0` to `100` by default. |
| `recording` | `field` | Whether a `hotkey` field records a key now. |
| `shake` | `field` | Whether a shake can be the key of a `hotkey` field. |
| `value` | `switch` | Whether the switch is on. |
| `type` | `switch` | `tick`, a round tick before its words. |
| `value` | `choice` | The id of the chosen option. |
| `type` | `choice` | The look: `list`, `swatches` or `multiple`. |
| `color` | `choice` | One colour of a `swatches` choice, one line for each. |
| `title` | `option` | The words of the option, its id by default. |

- A text field sends as the person types, and a slider as they drag.
- A `search` field searches the items, where the layout puts it.
- A switch or a choice closes the panel after it sends only with `close=true`.
