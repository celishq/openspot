# 10 Files a person writes

`final` `optional` · Needs 01 and 02.

A person writes these files by hand, in TOML, and Openspot reads them each time the panel opens.

## Widgets

A widget is a spot that shows metrics (02). It runs nothing (F8). Widgets live in a `.toml` file in the plugins folder:

```toml
[[widgets]]
name = "Morning"
layout = "hero"
places = ["agents", "battery", "cpu", "disk"]
opens = "links"
```

`places` names one metric by its ID for each cell, in order. `opens` is optional: it names the command that Enter or a
click runs, and `key` also works.

| Layout | Size | Places |
|---|---|---|
| `single` | 2x2 | One metric. `size` can ask for `small` (1x1) or `wide` (2x1). |
| `hero` | 4x2 | One large on the left, three lines on the right. |
| `pair` | 4x1 | Two. |
| `row` | 4x1 | Four values, each over its label. |

A widget can draw its own layout in the letters of a sheet's `grid` (02), with `places` as a table from letter to metric.
Each place takes its form from the room of its cell (H2).

```text
[[widgets]]
name = "Desk"
grid = ["a a b b", "a a c c", "a a d d"]
places = { a = "agents", b = "battery", c = "cpu", d = "disk" }
```

## Keys and the grid

`config.toml` in the config folder holds the keys that the person gives commands (01), and their choices for the grid.

```text
[[keys]]
spot = "music"
command = "pause"
key = "ctrl+option+p"
```

A key holds cmd, ctrl or option, with a letter, a digit, an arrow, space, return or tab. For the grid, a spot's `order`,
`size`, `grid` and `enabled` win over its header (F9).
