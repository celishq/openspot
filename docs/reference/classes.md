# Classes

`class=` on a block lays it out and styles it, with the names of Tailwind CSS, and each size and colour comes from
people's theme. A class that isn't here, such as `w-[120px]`, is skipped, and `openspot check spots` names it.

## Layout

| Class                                                     | Tailwind     | Is                                                     |
| --------------------------------------------------------- | ------------ | ------------------------------------------------------ |
| `flex-col`, `flex-row`                                    | the same     | A column, which a box is by default, or a row.         |
| `grid`, `grid-cols-<n>`                                   | the same     | A grid of `<n>` columns.                               |
| `col-span-<n>`, `row-span-<n>`                            | the same     | The cells a block covers in a grid.                    |
| `relative`                                                | the same     | A box of layers, one over the other.                   |
| `absolute`, `inset-0`, `top-0`, `right-0`, `bottom-0`, `left-0` | the same | A layer pinned to its box, or to one edge.       |
| `hidden`, `flex`                                          | the same     | A block that doesn't show, and one that does again.    |
| `items-start`, `items-center`, `items-end`, `items-stretch` | the same   | Where a box places its blocks across its line.         |
| `justify-start`, `justify-center`, `justify-end`, `justify-between` | the same | Where a box places its blocks along its line.  |
| `self-start`, `self-center`, `self-end`, `self-stretch`   | the same     | Where one block sits in a box that's larger.           |
| `grow`                                                    | the same     | Takes the free space of its row or column.             |
| `shrink-0`                                                | the same     | Never shrinks.                                         |
| `aspect-square`                                           | the same     | As wide as it's high.                                  |

## Space and size

| Class                                                     | Tailwind     | Is                                                     |
| --------------------------------------------------------- | ------------ | ------------------------------------------------------ |
| `p-<s>`, `px-<s>`, `py-<s>`, `pt-<s>`, `pr-<s>`, `pb-<s>`, `pl-<s>` | the same | The space inside a block.                      |
| `gap-<s>`, `gap-x-<s>`, `gap-y-<s>`                       | the same     | The space between the blocks of a box.                 |
| `gap-part`, `gap-group`, `p-part`, `p-group`              | none         | The gaps of Openspot's own sheets: between parts, and between groups. |
| `w-<z>`, `h-<z>`, `size-<z>`                              | the same     | The width, the height, or both.                        |
| `min-w-<z>`, `max-w-<z>`                                  | the same     | The least and the most width.                          |
| `min-h-<z>`                                               | the same     | The least height, which it keeps when its box runs out of room. |

- `<s>` is a step of Tailwind's scale, each 4 points: `0`, `0.5`, `1`, `1.5`, `2`, `2.5`, `3`, `3.5`, `4` to `12`, then
  `14`, `16`, `20` and on by 4 to `64`, then `72`, `80` and `96`.
- `<z>` is a step, `full`, `px` for one line, or a share: `1/2`, `1/3`, `2/3`, `1/4` or `3/4`.
- `<n>` is a count from 1 to 12.

## Words

| Class                                                     | Tailwind     | Is                                                     |
| --------------------------------------------------------- | ------------ | ------------------------------------------------------ |
| `font-title`, `font-detail`, `font-value`, `font-metric`, `font-section` | none | The fonts of Openspot's cards and sheets: a title, a second line, a value, a big number, a section head. |
| `font-medium`, `font-semibold`, `font-bold`               | the same     | The weight of the words.                               |
| `text-left`, `text-center`, `text-right`                  | the same     | Where the words sit.                                   |
| `truncate`                                                | the same     | Words cut at one line.                                 |
| `line-clamp-<n>`                                          | the same     | Words cut at `<n>` lines.                              |
| `tabular-nums`                                            | the same     | Digits of one width.                                   |
| `animate-pulse`                                           | none         | An icon breathes, layer by layer, as a loader, while the spot shows. |
| `animate-layout`                                          | none         | On the frame: when a new frame adds or drops blocks, they fade in and out, and the rest slide to their new places. |
| `sr-only`                                                 | the same     | Words that don't show, but VoiceOver reads.            |
| `text-ink`, `text-secondary`                              | none         | The colour of words, and of a second line.             |
| `text-accent`, `text-good`, `text-warn`, `text-bad`       | none         | The accent, and the colour of each tone.               |

## Fills, edges and corners

| Class                                                     | Tailwind     | Is                                                     |
| --------------------------------------------------------- | ------------ | ------------------------------------------------------ |
| `bg-tile`                                                 | none         | A tile, the fill of a grouped part.                    |
| `bg-accent`                                               | none         | The fill of the main button.                           |
| `bg-good`, `bg-warn`, `bg-bad`                            | none         | A fill of each tone.                                   |
| `bg-transparent`                                          | the same     | No fill.                                               |
| `backdrop-blur`                                           | the same     | A blur of what's behind.                               |
| `opacity-<p>`                                             | the same     | An opacity, `<p>` a percent from 0 to 100 in steps of 5. |
| `border`                                                  | the same     | A line around the block.                               |
| `overflow-hidden`                                         | the same     | Cuts what reaches past its edge.                       |
| `overflow-y-auto`                                         | the same     | On a box: its blocks scroll up and down when its box gives it less height than they need. |
| `rounded-card`, `rounded-inner`                           | none         | The corner of a card, and of a part inside it.         |
| `rounded-full`, `rounded-none`                            | the same     | A round end, and a square corner.                      |

`rounded-full` on a button makes a chip, or a round button of its `icon` when it has no `title`.

## Variants

A prefix applies a class only in a place or a state, such as `card:hidden` or `hover:bg-accent`.

| Prefix                                           | Tailwind            | Applies                                          |
| ------------------------------------------------ | ------------------- | ------------------------------------------------ |
| `sheet:`, `card:`, `bar:`, `float:`, `window:`, `toast:`, `details:` | none | In your sheet, a card, the menu bar, a float, a window, a [toast](commands.md#a-toast) or the [details of a chip](../connect/attachments.md#give-a-value). |
| `small:`, `wide:`, `square:`, `strip:`, `large:` | none                | On a card of that size.                          |
| `hover:`                                         | the same            | While the pointer is over it.                    |
| `pressed:`                                       | `active:`           | While it's pressed.                              |
| `selected:`                                      | `aria-selected:`    | While its row is selected.                       |
| `focus:`                                         | the same            | While it has the keys.                           |
| `dark:`, `light:`                                | `dark:`, none       | In the dark or the light look of the Mac.        |

Prefixes combine, such as `card:hover:bg-tile`, and a class with more prefixes wins over one with fewer.
