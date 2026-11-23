# Layouts

A layout places the blocks of a frame: `parent` puts a block inside a box, and `class` says how each box lays out what
it holds, with the class names of Tailwind CSS.

```ini
frame=
class=gap-3 p-3

box=head
class=flex-row items-center gap-2

icon=wifi
parent=head
value=wifi
class=text-accent

text=name
parent=head
title=Home
detail=82 Mb/s
class=grow

button=forget
parent=head
title=Forget
class=rounded-full

items=networks

item=office
parent=networks
title=Office
detail=54 Mb/s
```

A row of the Wi-Fi icon, Home and a Forget chip shows over a list of one network, Office.

- A frame has a layout when its root has a `class`, or when it holds an `items` block.
- A box lays out its blocks in a column, or in a row with `flex-row`, a grid with `grid grid-cols-<n>`, or layers with
  `relative`.
- Blocks that share a parent keep the order of their lines.
- `grow` takes the free space of a row or a column.
- The arrow keys move through each button, field, switch and choice in the order of the layout.

## Classes

Every size and colour comes from the person's theme, so a spot looks right in any theme.

| Class                                                     | Is                                                     |
| --------------------------------------------------------- | ------------------------------------------------------ |
| `flex-col`, `flex-row`                                    | A column, which a box is by default, or a row.         |
| `grid`, `grid-cols-<n>`, `col-span-<n>`, `row-span-<n>`   | A grid of `<n>` columns, and the cells a block covers. |
| `relative`, `absolute`, `inset-0`, `top-0`, `right-0`, `bottom-0`, `left-0` | Layers, and a layer pinned to its box or one edge. |
| `hidden`, `flex`                                          | A block that doesn't show, and one that does.          |
| `items-start`, `items-center`, `items-end`, `items-stretch` | Where a box places its blocks across its line.         |
| `justify-start`, `justify-center`, `justify-end`, `justify-between` | Where a box places its blocks along its line.          |
| `self-start`, `self-center`, `self-end`, `self-stretch` | Where a block sits in a box that's larger.             |
| `p-<s>`, `px-<s>`, `py-<s>`, `pt-<s>`, `pr-<s>`, `pb-<s>`, `pl-<s>` | The space inside a block.                    |
| `gap-<s>`, `gap-x-<s>`, `gap-y-<s>`                       | The space between the blocks of a box.                 |
| `w-<s>`, `h-<s>`, `size-<s>`, `min-w-<s>`, `max-w-<s>`    | The width, the height, or both.                        |
| `grow`, `shrink-0`, `aspect-square`                       | A block that takes the free space, never shrinks, or is square. |
| `font-title`, `font-detail`, `font-metric`, `font-value`, `font-section` | The fonts of Openspot's cards and sheets. |
| `font-medium`, `font-semibold`, `font-bold`               | The weight of the words.                               |
| `text-left`, `text-center`, `text-right`                  | Where the words sit.                                   |
| `truncate`, `line-clamp-<n>`, `tabular-nums`, `sr-only`   | Words cut at one line or `<n>` lines, digits of one width, or words that don't show. |
| `text-ink`, `text-secondary`, `text-accent`, `text-good`, `text-warn`, `text-bad` | The colour of the words.       |
| `bg-tile`, `bg-accent`, `bg-transparent`                  | A tile, the main button, or no box.                    |
| `bg-good`, `bg-warn`, `bg-bad`                            | A fill of each tone.                                   |
| `backdrop-blur`, `opacity-<p>`, `border`, `overflow-hidden` | A blur, an opacity, a line around the block, and a cut at its edge. |
| `rounded-card`, `rounded-inner`, `rounded-full`, `rounded-none` | The corner of a block.                           |

- `<s>` is a step of Tailwind's scale from `0` to `96`, each 4 points, or `full`, a share such as `1/2`, or `px`.
  `gap-part` and `gap-group` are the gaps of Openspot's own sheets.
- `<n>` is a count from 1 to 12, and `<p>` a percent in steps of 5.
- `rounded-full` on a button makes a chip, or a round button of its `icon` when it has no `title`.
- A divider is a box with `class=h-px bg-tile`.
- A class that isn't here, such as `w-[120px]`, is skipped.

## Variants

A variant is a prefix that applies a class only in a place or a state, as Tailwind's `hover:` does.

```ini
button=play
title=Play
class=bg-tile hover:bg-accent card:hidden
```

| Prefix                                           | Applies                                          |
| ------------------------------------------------ | ------------------------------------------------ |
| `sheet:`, `card:`, `bar:`, `float:`, `window:`   | In that [place](11-places.md).                   |
| `small:`, `wide:`, `square:`, `strip:`, `large:` | On a card of that size.                          |
| `hover:`, `pressed:`, `selected:`, `focus:`      | While the pointer is over it, it's pressed, its item is selected, or it has the keys. |
| `dark:`, `light:`                                | In that appearance of the Mac.                   |

- Prefixes combine, such as `card:hover:bg-tile`.
- A class with more prefixes wins over one with fewer.
