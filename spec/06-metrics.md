# 06 Metrics

`final` · Needs 01.

## Metrics

A metric is one piece of live data. Any widget can show the value of any script with a `read`, by its ID, which is its path with no extension, such as `coffee` or `home/coffee`. A script with a number in its `read` keeps the value fresh, and it has no spot unless it also has a `key`.

File `coffee.sh`:

```sh
#!/bin/sh
# name=Cups today
# symbol=cup.and.saucer.fill
# read=60
printf 'title=3\ndetail=Last at 14:20\n'
```

Openspot reads a metric only when a widget places it and the panel is open, or when the menu bar shows it.
When a read fails, the last value stays and dims.

`name` says what the metric measures, and each place shows it. Do not repeat it in the values. `symbol` can also be
printed, when it changes.

Marks are white. A `tone` colours a mark to say what it means: `good`, `warn` or `bad`. Use it only when the colour means
something. `tint` also colours the mark, and it is optional: use red, orange, yellow, green, mint, teal, cyan, blue,
indigo, purple or pink, and only when the colour helps a person find one metric among many. Text stays white.

What a metric prints decides how it shows:

| Prints | Shows |
|---|---|
| `title` | A number or a word. |
| `title` and `value=0.84`, from 0 to 1 | A ring. |
| `title` and one `point=2` line for each bar | Bars from zero. The last bar is the newest. `max=100` sets a fixed top value. |
| `title` and `tone`, with no `symbol` | A dot with a word. |
| A block with `row=Build` for each row | Short lines, as many as fit. Each can have `detail=2m` and `tone=good`. `title` is the count unless you print one. |

## Widgets

A widget is a spot that shows metrics in a layout. It runs nothing, and it can place metrics of any plugin. Widgets live
in a `.toml` file in the plugins folder:

```toml
[[widgets]]
name = "Morning"
layout = "hero"
places = ["agents", "battery", "cpu", "disk"]
opens = "links"
```

`places` fills the cells of the layout in order, and each cell needs one metric. `opens` is optional: it names the
command that Enter or a click runs. `key` also works. Its sheet grows out of the widget. Give that
command `grid=false`, so that it has no card of its own.

A widget can also draw its own layout, in the same letters as a sheet's `grid`. Each letter is a rectangle, `.` is empty,
and `places` names a metric for each letter:

```toml
[[widgets]]
name = "Desk"
grid = ["a a b b", "a a c c", "a a d d"]
places = { a = "agents", b = "battery", c = "cpu", d = "disk" }
```

A one-line drawing is a `strip` and any other is `large`, unless `size` asks for another. The app sets the gaps, and each
place takes its form from the room its cell has: a cell with two columns and two rows shows the large form, a shorter one
a line, and one column of the card only the value.

| Layout | Size | Places |
|---|---|---|
| `single` | 2x2 | One metric. Use `size` to ask for `small` (1x1) or `wide` (2x1). |
| `hero` | 4x2 | One large on the left, three lines on the right. |
| `pair` | 4x1 | Two, each with its mark at the outer edge. |
| `row` | 4x1 | Four values, each over its label. |

A size is a preference. The grid fills each row: four small spots stay 1x1, and fewer than four grow. The same is true
for a command with `size=small`, which shows only its symbol.

A large place shows the detail. In a `hero` line, a trend with `max` shows as one bar. Other places show only the label,
the value and the mark, so keep the title short, such as `84%`.

## The menu bar

Add `tray=true` to the header of a metric to show it in the menu bar. It needs no widget, and it needs a number in its
`read`, or `stay=true`. Openspot then reads it all the time, so choose a `read` that is not too short.

A click opens the panel on the metric's list if it also has a `key`. If not, the panel opens and selects a widget that
places it.

The item shows the metric's `symbol` and its mark. Rows show one count for each `tone`, worst first. A ring, bars and a
dot show small, and a `title` shows as text.

Print nothing to remove the item until the next read, such as when nothing is running. Widgets in the panel still show
the metric.

## Rules

| ID | Rule |
|---|---|
| F7 | A script with a number in its `read` and no `key` has no spot. A widget or the menu bar can show it. |
| F8 | Widgets are in a `.toml` file, because a person writes them by hand. A widget runs nothing. |
| H1 | A widget or the menu bar can show any script with a `read`, by its ID. A failed read keeps the last value, dimmed. |
| H2 | A widget places metrics in a named layout or a `grid` drawing. Each place takes its form from the room of its cell. |
