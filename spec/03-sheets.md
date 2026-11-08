# 03 Sheets

`final` · Needs 01.

A script that prints parts opens a sheet of them, with no search field. Run `openspot catalog` for the whole language,
with examples. A model can write a good sheet from that text alone.

A sheet is a drawing and parts. Draw it with one letter for each area, and a part takes a letter with `cell`. The words of a
line set the columns, so a wider area takes more words. A smaller area on a larger one floats, with its own background:

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

Each row has one height, so a taller area takes more lines. Rows that hold text, a list, a chart or a picture share the free
height. A letter with no part stays empty.

With no drawing, a sheet is one column of lines, and `section=<id>` starts a new group with a divider.

The app owns each gap, row height and centre. A script says only which part goes where, and cannot make an uneven sheet.

| Prints | Shows | Openspot calls |
|---|---|---|
| `title`, `detail`, `symbol` | A line, with a value on the right. | |
| A line with `value=0.84`, or `point=3` lines and `max` | A small bar or bars before the value, as a widget draws them. `tone` colours it. | |
| `on=true` | A switch. | `<id> true` or `false` |
| `level=70`, `min`, `max` | A slider. | `<id> <number>` |
| `color=#ff0000` for each swatch, `value` | A row of colours. | `<id> <color>` |
| `option=en:English` for each choice, `value` | A menu. | `<id> <option id>` |
| `item=a:Address` for each row, `value` | A list to choose from. | `<id> <item id>` |
| `shortcut=ctrl+space`, with `title` | A key that a click records. | `<id> <key>` |
| `text=...`, `placeholder` | A text area. `readonly=true` only shows the text. | `<id> <text>` |
| `press=arrow.clockwise` | A round button. | `<id>` |
| `press=true` | A button that fills its cell. | `<id>` |
| `metric=42%`, `point=3`, `image=<path>`, `block=progress` | A number, a chart, a picture, a progress bar. | |
| `keys=7 8 9 +` in the layout block | A row of key buttons. | `<word>` |

The script holds no state. Each call gets all values on stdin, as one block such as `input=one\ntwo`. It prints the
whole sheet again, or prints nothing to be read again. It can also print `toast=Saved`. To read an open sheet again every 5
seconds, put a number in its header: `read=5`.

Openspot shows a change at once, and only the answer to the newest change shows. It waits for a pause in typing and in
a slider's motion. Text that the person is typing stays as typed until they press something.

Closing the panel closes a sheet of parts and drops its values, and the next open reads again. A sheet of rows stays open.

To read the sheet when the panel opens, so that it opens at its full size, use `read=panel`. Otherwise use `read=sheet`.

To try a sheet, run `openspot sandbox`, or `openspot sandbox <file>` to watch a file or run a script. It shows the real
sheet and its faults at once. `openspot check --sheet` reports the faults of a sheet on stdin, and `openspot render
<file.png>` draws it to a picture.

## Rules

| ID | Rule |
|---|---|
| B1 | A sheet draws its layout with `grid=` lines. There are no named layouts. |
| B2 | The words of a `grid=` line set the columns, so there is no width to set. |
| B3 | Each row has one height and each gap one size, and the app owns both. |
| B4 | Rows that hold text, a picture, a chart, a list or a repeated area share the free height. |
| B5 | `repeat=<letter> <per line>` flows the rows into one area, which scrolls. |
| B6 | A complex view is a Swift block in the app, which a script names and fills with data. |
| G5 | A sheet of parts can show a part with `block=progress`. |
| K5 | Closing the panel closes a sheet of parts and drops its values. A sheet of rows stays open. |

## Why not

| Decision | Why | Rejected |
|---|---|---|
| A sheet is a drawing, with one row height | A model writes one form, and each result stays even. | Named layouts, ratios and nested drawings. |
| Complex views are Swift blocks in the app | The text language stays small, and a plugin never draws in Openspot. | A view in a plugin now. |
