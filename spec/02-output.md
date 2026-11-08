# 02 What a script prints

`draft` `required` · Needs 01.

```text
grid=title title title title
grid=wifi  wifi  wifi  wifi
grid=nets  nets  nets  nets

text=title
title=Wi-Fi
detail=Home · 82 Mb/s

switch=wifi
title=Wi-Fi
on=true

repeat=nets

row=Home
run=home
symbol=wifi
tone=on

row=Office
run=office
symbol=wifi

button=forget
title=Forget
key=cmd+backspace
confirm=Press again to forget
```

A script prints components, and a drawing places them (R1). The app owns each canvas, each size, each gap and each
colour. A script says only what goes where.

## Components

A component is one block. Its first line is `<kind>=<id>`: the key is the kind, and the value is its id (U2). This is not
the `key=value` of a setting: the key says what the block is, and the value names it. The id names the area that the
component fills, the event that it sends, and the thing that moves when it changes. Ids are unique in one output, and a
component cannot take a default id of 01 (C1).

| Kind      | Shows                                                   | Its own keys                                                    | Sends                  |
| --------- | ------------------------------------------------------- | --------------------------------------------------------------- | ---------------------- |
| `text`    | Words, or a number with `look=large`.                   | `look`                                                          |                        |
| `gauge`   | A ring in a square area, a bar in a wide one.           | `value` from 0 to 1                                             |                        |
| `graph`   | Bars. The last bar is the newest.                       | `point`, one line for each bar, and `max`                       |                        |
| `picture` | A picture that fills its area.                          | `symbol`, `file`, `image` or `glyph`                            |                        |
| `view`    | The SwiftUI view that the header names (03).            | any key that the view reads                                     |                        |
| `switch`  | A switch.                                               | `on`                                                            | `<id> true` or `false` |
| `slider`  | A slider. It sends when the person lets go.             | `level`, `min`, `max`                                           | `<id> <number>`        |
| `field`   | A text field.                                           | `text`, `placeholder`, `type=multiline`, `required`, `readonly` | `<id> <text>`          |
| `choice`  | A menu of `option` lines, or swatches of `color` lines. | `option=<id>:<title>`, `color`, `value`                         | `<id> <option id>`     |
| `key`     | A key that a press records.                             | `shortcut`                                                      | `<id> <key>`           |
| `button`  | A button, or an action (see below).                     | `key`, `confirm`, `close`, `look`, `form`, `scope`              | `<id>`                 |
| `section` | A title over the lines that follow it.                  |                                                                 |                        |
| `repeat`  | The rows of the output (see Repeats).                   | `grid` lines                                                    |                        |

Each kind also takes `title`, `detail`, `tone` and a picture: `symbol`, `file`, `image` or `glyph` (U3). `tone` is `good`,
`warn` or `bad` for a colour that means something, and `on` for a plain dot that says that a thing is active. `look` is
`tile`, `chip`, `strong`, `bare` or `key` on a button, and `large` on a text. A key that a kind does not take is skipped.

## Drawings

A drawing places components. Each `grid=` line of the head is one line of the sheet, and each word is one cell (B1). A
word is the id of a component, `.` is an empty cell, and `-` draws a divider across the line. The words of a line set the
columns, so there is no width to set (B2). A component fills the rectangle of cells that its id covers, and each id covers
a rectangle (U4). A smaller component that lies in a larger one sits on top of it, at the edge it touches. `card=` lines
group areas onto one raised card.

`grid.<place>=` lines draw another place of the spot: `small`, `wide`, `square`, `strip` and `large` for its card, and
`tray` for the menu bar (U5). A card's drawing can have more lines than the card has rows: the app divides its room
evenly. A place with no drawing takes the drawing of the nearest smaller size, and a spot with none keeps its default card.

With no `grid=` line, the sheet is one column of its components other than buttons, in the order that they print, and a
`section` starts a new group. `keys=7 8 9 +` in the head draws a line of keys, and a press of one sends `<word>`.

## Buttons and actions

A `button` that a drawing places is drawn. A `button` that no drawing places is an action (U6): it shows in the ⌘K menu,
its `key` works directly, and with no row selected it acts on the whole spot. An action on a row is `<script> <id> <run>`.
`scope=command` keeps an action on the whole spot when a row is selected. `close=true` closes the panel after it runs, and
`confirm` asks for a second press, such as `Press again to delete`.

`button=open` sets what Enter does on a row: `title` is its word, and `close=false` keeps the panel open after a pick.

A button with `form=true` asks for values first. The call runs once with empty stdin, and it prints a `title` in its head
and one `field` for each value. Then the same call runs with the values on stdin, and it can print the `run` of the row to
select (C3).

## Rows

A `row` block is one item: `row` is its title, and `run` is the value that a pick sends as `<script> open <run>`. With no
`repeat`, the rows fill the sheet as a list.

| Key                                | Meaning                                                                        |
| ---------------------------------- | ------------------------------------------------------------------------------ |
| `row`, `run`                       | Required.                                                                      |
| `detail`                           | The second line.                                                               |
| `symbol`, `file`, `image`, `glyph` | The picture.                                                                   |
| `tone`                             | A dot on the picture.                                                          |
| `hides`                            | The id of a button that this row does not offer. Repeat the line for each one. |
| `keyword`                          | A word that finds the row in a search, which the row does not show.            |
| `shortcut`                         | A key at the end of the row. A pick records a new key and calls `<run> <key>`. |
| `as`                               | The template that draws this row.                                              |
| `<slot>`, `<slot>.<key>`           | The value of a slot of its template, and any other key of that slot.           |

Openspot searches the rows itself and sorts recent picks first. The head can change this on each read:

- `search=script` sends each search change as `<script> read <text>`, and the script prints the rows that match (R6).
- `recents=false` does not sort recent picks first (R7).

`global=true` in the header shows the rows in the main search too. It needs `panel`, `launch` or a number in its `read`,
and a number also needs a `key`. Openspot ranks them by the person's picks, and the script cannot.

## Repeats and templates

A `repeat` flows the rows through its area (B5). Its own `grid=` lines are a drawing in which each word is the place of
one row, and the drawing repeats down for as long as there are rows (U7). Rows take the places in the order in which each
word first shows.

```text
repeat=photos          repeat=emoji                 repeat=apps
grid=a a b c           grid=a b c d e f g           grid=a
grid=a a d e
```

The first is a bento of one large place and four small ones, the second is a grid of seven to a line, and the third, the
default, is a list.

A `template` block draws a row. Each `<kind>=<slot>` line in it gives a slot a kind, and its `grid=` lines place the slots.
`grid.<columns>x<rows>=` lines draw the row in a place of that many cells of the repeat, such as `grid.2x2=` for the large
place of a bento, and a place with no drawing of its size takes the nearest smaller one (U8). A row picks a template with
`as=<name>`, and `template=row` draws each row that names none. A row with no template draws its picture, its `row` and
`detail`, its `tone` and its `shortcut`.

```text
template=row
grid=pic name . quit
picture=pic
text=name
button=quit
quit.symbol=xmark.circle

row=Safari
run=/Applications/Safari.app
pic.file=/Applications/Safari.app
name=Safari
tone=on
```

A row fills a slot by its id. `<slot>=<value>` sets the main key of the slot's kind: `title` on a text and a button,
`value` on a gauge, `point` on a graph, `on` on a switch, `level` on a slider, `text` on a field, `value` on a choice, and
`shortcut` on a key. `<slot>.<key>=` sets any other key, in the template for each row or in the row for one row. A control
in a row sends `<script> <slot> <run> [value]` (U9), and a row hides one with `hides=<slot>`.

## Values and frames

The script holds no state. Each call gets the value of each switch, slider, field, choice and key on stdin as one block,
and it prints the whole output again, or nothing to be read again (B6). The app draws a change at once, and drops the
answer to a call that a newer change has outdated (U10). A repeat keeps its rows until a frame prints rows again, so a
frame can change one switch alone (U11).

The head is the first block with no kind. It holds the drawings, `title` and `detail` for the spot's card, `tone=on` for
a card that shows that its thing is on, `size`, `search`, `recents`, `toast` and `open`. A head is not drawn.

## The card

A spot with no `grid.<size>=` draws its default card: its picture, its title, its detail, and an arrow when it has a
sheet (U12). A spot whose output is one `switch` or one `slider` and nothing else draws that control as its card, with the
control's `title` and `detail`, and a press of the card changes it.

A press on a card area that is not a control opens the spot's sheet, or calls `<script> run` when it has none.

## Metrics

A metric is a spot with a number in its `read`, and the first `text`, `gauge` or `graph` that it prints is its value. A
widget or the menu bar can show any script with a `read`, by its ID (H1). A script with a number in its `read` and no
`key` has no spot of its own (F7).

```sh
#!/bin/sh
# name=Cups today
# symbol=cup.and.saucer.fill
# read=60
printf 'text=cups\ntitle=3\ndetail=Last at 14:20\n'
```

`tray=true` in the header shows the metric in the menu bar. It needs a number in its `read`. A `grid.tray=` drawing
chooses what the menu bar shows. Printing nothing removes the item until the next read.

## Decisions

| Decision                                                                                                    | Rejected                                     |
| ----------------------------------------------------------------------------------------------------------- | -------------------------------------------- |
| A component is `<kind>=<id>`, so a block says what it is and where it goes in one line.                     | `part=<id>` with a kind found from its keys. |
| The app owns each canvas, and a drawing only names areas, so each result stays even.                        | Sizes, gaps and colours in points.           |
| A drawing is CSS grid areas, which authors and models know.                                                 | Nested stacks, ratios and named layouts.     |
| A button that no drawing places is an action, so a verb is one kind in two places.                          | An `action` block beside a `button`.         |
| A template draws a row, and a repeat's drawing places rows, so lists, grids and bentos are one rule.        | `repeat=<area> <per line>` in the head.      |
| A form is the same call twice, so each call has one shape.                                                  | A `form` word.                               |
| A complex view is a `view` of the plugin in an area, so the text language stays small.                      | More words for each new look.                |

## What the app does not do yet

| Rule       | Today                                                                               | Phase |
| ---------- | ----------------------------------------------------------------------------------- | ----- |
| U8, U9     | A row cannot draw a `field` slot; a list row has room for two lines.                | 2     |
| U11        | A frame replaces the rows.                                                          | 2     |
