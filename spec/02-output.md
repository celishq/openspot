# 02 What a script prints

`final` `optional` · Needs 01.

What a script prints decides how its spot shows: rows or actions make a list, parts make a sheet, `on` a toggle, `level`
a slider, and a value with no rows a metric (R1).

## Rows

Each row is one block. `row` and `run` are required.

```text
row=Safari
detail=App
run=/Applications/Safari.app
file=/Applications/Safari.app
```

| Key                                | Meaning                                                                                                     |
| ---------------------------------- | ----------------------------------------------------------------------------------------------------------- |
| `row`                              | The title.                                                                                                  |
| `run`                              | The value that a pick sends: `<script> open <run>`.                                                         |
| `detail`                           | The second line.                                                                                            |
| `symbol`, `file`, `image`, `glyph` | The picture: an SF Symbol, a file's icon, a path to an image, or a short text such as an emoji.             |
| `hides`                            | The id of an action that this row does not offer. Repeat the line for each one.                             |
| `keyword`                          | A word that finds the row in a search, which the row does not show. Repeat the line for each one.           |
| `shortcut`                         | A key, such as `ctrl+space`, shown at the end of the row. A pick records a new key and calls `<run> <key>`. |

Openspot searches the rows itself and sorts recent picks first. The head can change this on each read:

- `search=script` sends each search change as `<script> read <text> [form]...`, and the script prints the rows that match
  any of them (R6). A form is another text that the person may have meant, such as the text typed in another keyboard
  layout or spelled in Latin letters.
- `recents=false` does not sort recent picks first (R7).
- `repeat=<letter> <per line>` flows the rows as square buttons into one area of the drawing, which scrolls (B5).

`global=true` in the header shows the rows in the main search too. It needs `panel`, `launch` or a number in its `read`,
and a number also needs a `key`. Openspot ranks them by the person's picks, and the script cannot.

## Actions and forms

An action is an extra thing to do on a row, or with `scope=command` on the whole list. Its call is
`<script> <action> <run>`.

```text
action=copy
title=Copy
key=cmd+return
close=true
```

| Key               | Meaning                                                             |
| ----------------- | ------------------------------------------------------------------- |
| `action`, `title` | Required.                                                           |
| `key`             | Such as `cmd+e`, `cmd+return` or `cmd+shift+d`.                     |
| `scope`           | `command` for an action that needs no selected row.                 |
| `close`           | `true` to close the panel after it runs.                            |
| `confirm`         | Words that ask for a second press, such as `Press again to delete`. |
| `form`            | `true` to ask for values first.                                     |

`action=open` sets what Enter does on a row: `title` is its word, and `close=false` keeps the panel open after a pick.

A form is the same call twice (C3). First it runs with empty stdin, and it prints a block with the `title`, then one block
for each field. Then it runs with the values on stdin, as one block such as `text=one\ntwo`, and it can print the `run` of
the row to select.

```text
title=New note

field=text
label=Text
type=multiline
required=true
```

A field needs `field` and `label`. `type` is `text` (the default) or `multiline`. `value` and `placeholder` are optional.

## Toggles and sliders

With `read=panel`, one block makes a toggle or a slider. Both can print `title` and `detail`.

| Prints                         | Shows     | Call             |
| ------------------------------ | --------- | ---------------- |
| `on=true` or `on=false`        | A toggle. | `on` or `off`    |
| `level=70`, `min=0`, `max=100` | A slider. | `level <number>` |

## Sheets

Parts make a sheet. The head draws its layout with `grid=` lines: one letter for each area, and a part takes a letter with
`cell` (B1). The words of a line set the columns, so there is no width to set (B2). A letter with no part stays empty, and
`.` is empty too. With no drawing, a sheet is one column, and `section=<id>` starts a new group.

```text
grid=t t t t
grid=t t t c

part=note
cell=t
text=Buy milk

part=save
cell=c
look=strong
press=checkmark
```

`openspot catalog` prints each part, each key and each look, with examples, and it is the source for them. A part sends
its id and its new value:

| A part with                | Call                   |
| -------------------------- | ---------------------- |
| `on`                       | `<id> true` or `false` |
| `level`, `min`, `max`      | `<id> <number>`        |
| `color` lines              | `<id> <color>`         |
| `option` or `item` lines   | `<id> <option id>`     |
| `shortcut`                 | `<id> <key>`           |
| `text`                     | `<id> <text>`          |
| `press`                    | `<id>`                 |
| `keys=7 8 9 +` in the head | `<word>`               |

The script holds no state. Each call gets all values of the sheet on stdin as one block, and it prints the whole sheet
again, or nothing to be read again. A complex view is a view of the app, which a script names and fills with data (B6).

## Metrics

A metric is one live value. A widget or the menu bar can show any script with a `read`, by its ID (H1). A script with a
number in its `read` and no `key` has no spot of its own (F7).

```sh
#!/bin/sh
# name=Cups today
# symbol=cup.and.saucer.fill
# read=60
printf 'title=3\ndetail=Last at 14:20\n'
```

| Prints                                                              | Shows                                                           |
| ------------------------------------------------------------------- | --------------------------------------------------------------- |
| `title`                                                             | A number or a word.                                             |
| `title` and `value=0.84`, from 0 to 1                               | A ring.                                                         |
| `title` and one `point=2` line for each bar, with an optional `max` | Bars. The last bar is the newest.                               |
| `title` and `tone`, with no `symbol`                                | A dot with a word.                                              |
| `row` blocks, each with an optional `detail` and `tone`             | Short lines. `title` is the count unless the script prints one. |

`name` says what the metric measures, so the values do not repeat it. `tone` is `good`, `warn` or `bad`, for a colour that
means something. `tint` is a colour name, such as `teal`, for a colour that only helps a person find the metric. A printed
`symbol` changes the symbol of the header.

`tray=true` in the header shows the metric in the menu bar. It needs a number in its `read`. Printing
nothing removes the item until the next read.

## Decisions

| Decision                                                                                         | Rejected                                   |
| ------------------------------------------------------------------------------------------------ | ------------------------------------------ |
| A form is the same call twice, so each call has one shape.                                       | A `form` word.                             |
| A sheet is a drawing with one row height, so a model writes one form and each result stays even. | Named layouts, ratios and nested drawings. |
| A complex view is a view of the app, so the text language stays small.                           | A view in each plugin's text.              |
