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

row=home
title=Home
icon=wifi
tone=on

row=office
title=Office
icon=wifi

button=forget
title=Forget
shortcut=cmd+backspace
confirm=Press again to forget
```

A script prints components, and a drawing places them. The app owns each canvas, each size, each gap and each
colour. A script says only what goes where.

## Components

A component is one block. Its first line is `<kind>=<id>`: the key is the kind, and the value is its id (U2). The id names the area that the
component fills, the event that it sends, and the thing that moves when it changes. Ids are unique in one output, and a
component cannot take a default id of 01.

| Kind      | Shows                                                   | Its own keys                                                    | Sends                  |
| --------- | ------------------------------------------------------- | --------------------------------------------------------------- | ---------------------- |
| `text`    | Words.                                                  |                                                                 |                        |
| `number`  | A big number, with its `title` under it.                | `value`                                                         |                        |
| `gauge`   | A ring in a square area, a bar in a wide one.           | `value` from 0 to 1                                             |                        |
| `graph`   | Bars. The last bar is the newest.                       | `point`, one line for each bar, and `max`                       |                        |
| `picture` | A picture that fills its area.                          | `icon`                                                          |                        |
| `view`    | The SwiftUI view that the header names (03).            | any key that the view reads                                     |                        |
| `spot`    | The value of the spot with this id, as a widget shows it. |                                                               |                        |
| `switch`  | A switch.                                               | `on`                                                            | `<id> true` or `false` |
| `slider`  | A slider. It sends when the person lets go.             | `level`, `min`, `max`                                           | `<id> <number>`        |
| `field`   | A text field.                                           | `text`, `placeholder`, `type=multiline`, `required`, `readonly` | `<id> <text>`          |
| `choice`  | A menu of `option` lines, a list when it covers two lines or more, or swatches of `color` lines. | `option=<id>:<title>`, `color`, `value`                         | `<id> <option id>`     |
| `hotkey`  | A key combination that a press records.                 | `value`                                                         | `<id> <shortcut>`      |
| `button`  | A button, or an action (see below).                     | `shortcut`, `confirm`, `close`, `look`, `form`, `scope`         | `<id>`                 |
| `section` | A title over the lines that follow it.                  |                                                                 |                        |
| `repeat`  | The rows of the output (see Repeats).                   | `grid` lines                                                    |                        |

Each kind also takes `title`, `detail`, `tone` and `icon`. The value of `icon` says what the picture is: a path
of a picture file, such as `cups.png`, draws the picture; any other path draws the file's Finder icon; a name of lowercase
letters, digits and dots, such as `wifi`, is an SF Symbol; and any other text, such as `😀`, is drawn as it is. `tone` is `good`,
`warn` or `bad` for a colour that means something, and `on` for a plain dot that says that a thing is active. `look` is
the box of a text, a number or a button: `tile`, `bare`, and on a button also `chip` or `strong`. A key that a kind does not take is skipped.

## Drawings

A drawing places components. Each `grid=` line of the head is one line of the sheet, and each word is one cell. A
word is the id of a component, `.` is an empty cell, and `-` draws a divider across the line. The words of a line set the
columns, so there is no width to set. A component fills the rectangle of cells that its id covers, and each id covers
a rectangle (U4). A smaller component that lies in a larger one sits on top of it, at the edge it touches. `card=` lines
group areas onto one raised card.

`grid.<size>=` lines draw the spot's card at a size: `small`, `wide`, `square`, `strip` or `large` (U5). A card's drawing can have more lines than the card has rows: the app divides its room
evenly. A place with no drawing takes the drawing of the nearest smaller size, and a spot with none keeps its default card.

With no `grid=` line, the sheet takes its default drawing: one column of each component that is not a button, in the order
that they print, then its rows (U13). A `section` starts a new group. A drawing names a button only when the script draws
one, so a button with no drawing of its own is always an action. `pad=7 8 9 +` in the head draws a line of keypad buttons, and a press of one sends `<word>`.

## Buttons and actions

A `button` that a drawing places is drawn. A `button` that no drawing places is an action (U6): it shows in the ⌘K menu,
its `shortcut` works directly, and with no row selected it acts on the whole spot. An action on a row is `<script> <id> <row id>`.
`scope=command` keeps an action on the whole spot when a row is selected. `close=true` closes the panel after it runs, and
`confirm` asks for a second press, such as `Press again to delete`.

Enter on a row is the action `open`, which each spot has. A `button=open` gives it its word with `title`, and
`close=false` keeps the panel open after a pick.

A button with `form=true` asks for values first. The call runs once with empty stdin, and it prints a `title` in its head
and one `field` for each value. Then the same call runs with the values on stdin, and it can print the id of the row to
select.

## Rows

A `row` block is one item: `row=<id>` names it, and a pick sends `<script> open <id>`. Its `title` is the words it shows, and with no `title` it shows its id. Rows
always flow through a repeat, and with no `repeat` block they flow through a list.

| Key                                | Meaning                                                                        |
| ---------------------------------- | ------------------------------------------------------------------------------ |
| `row`                              | Required: the id.                                                              |
| `title`                            | The first line. Its id, when it has none.                                      |
| `detail`                           | The second line.                                                               |
| `icon`                             | The picture.                                                                   |
| `tone`                             | A dot on the picture.                                                          |
| `hides`                            | The id of a button that this row does not offer. Repeat the line for each one. |
| `keyword`                          | A word that finds the row in a search, which the row does not show.            |
| `shortcut`                         | A key at the end of the row. A pick records a new key and calls `<id> <shortcut>`. |
| `as`                               | The template that draws this row.                                              |
| `<slot>`, `<slot>.<key>`           | The value of a slot of its template, and any other key of that slot.           |

Openspot searches the rows itself and sorts recent picks first. The head can change this on each read:

- `search=script` sends each search change as `<script> read <text>`, and the script prints the rows that match.
- `recents=false` does not sort recent picks first.

## Repeats and templates

A `repeat` flows the rows through its area. Its own `grid=` lines are a drawing in which each word is the place of
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
place of a bento, and a place with no drawing of its size takes the nearest smaller one (U8). In a list, a row takes one row height for each
two lines of its drawing. A row picks a template with
`as=<name>`, and `template=row` draws each row that names none. With no template, a row is drawn by the default template:
its own keys `title`, `detail`, `icon`, `tone` and `shortcut` are its slots, as a picture, its
words, a dot and a key. A slot of a template cannot take the name of a key of a row (U14).

```text
template=row
grid=pic name . quit
picture=pic
text=name
button=quit
quit.icon=xmark.circle

row=/Applications/Safari.app
title=Safari
pic.icon=/Applications/Safari.app
name=Safari
tone=on
```

A row fills a slot by its id. `<slot>=<value>` sets the main key of the slot's kind: `title` on a text and a button,
`value` on a gauge, `point` on a graph, `on` on a switch, `level` on a slider, `text` on a field, `value` on a choice and a hotkey. `<slot>.<key>=` sets any other key, in the template for each row or in the row for one row. A control
in a row sends `<script> <slot> <row id> [value]` (U9), and a row hides one with `hides=<slot>`.

## Values and frames

The script holds no state. Each call gets the values on stdin (01), and prints the whole output again, or nothing to be
read again. The app draws a change at once, and drops the
answer to a call that a newer change has outdated (U10). The first frame of a read replaces all that the spot shows, and
each later frame of the same read changes only what it prints.

The head is the one block with no kind, at any place in the output, and it is not drawn. It holds four groups:

- the drawing: `grid=`, `card=` and `pad=` lines for the sheet, and `grid.<size>=` lines for the card;
- the spot: `main`, and `title`, `detail` and `size` for its card;
- the rows: `search` and `recents`;
- the effects: `toast`, `link=<url>`, which opens the URL, and `end=<call>`, which ends a call of a staying script (05).

A second block with no kind is skipped, and Openspot reports it.

## The main component

`main=<id>` in the head names the component that stands for the spot (H1). With no `main=`, the only `text`, `number`, `gauge`,
`graph`, `switch` or `slider` of the output stands for it, and with two or more, none does. The menu bar, a widget and a
`spot` component show a main `text`, `number`, `gauge` or `graph`. A main `switch` shows on the card whether its thing is
on, also when the switch is in the sheet. A main `gauge` is the progress of a call that runs.

## The card

A spot with no `grid.<size>=` draws its default card: its picture, its title, its detail, and an arrow when it has a
sheet (U12). A spot whose output is one `switch` or one `slider` and nothing else draws that control as its card, with the
control's `title` and `detail`, and a press of the card changes it.

A press on a card area that is not a control opens the spot's sheet, or calls `<script> run` when it has none.

## Metrics

A metric is a spot with a number in its `read`, and its main component is a `text`, a `number`, a `gauge` or a `graph`. A
widget or the menu bar can show any script with a `read`, by its ID (H1). A script with a number in its `read` and no
`shortcut` has no spot of its own (F7).

```sh
#!/bin/sh
# title=Cups today
# icon=cup.and.saucer.fill
# read=60
printf 'text=cups\ntitle=3\ndetail=Last at 14:20\n'
```

`tray=true` in the header (01) shows it in the menu bar.

## Decisions

| Decision                                                                                                    | Rejected                                     |
| ----------------------------------------------------------------------------------------------------------- | -------------------------------------------- |
| A component is `<kind>=<id>`, so a block says what it is and where it goes in one line.                     | `part=<id>` with a kind found from its keys. |
| The app owns each canvas, and a drawing only names areas, so each result stays even.                        | Sizes, gaps and colours in points.           |
| A drawing is CSS grid areas, which authors and models know.                                                 | Nested stacks, ratios and named layouts.     |
| A button that no drawing places is an action, so a verb is one kind in two places.                          | An `action` block beside a `button`.         |
| A template draws a row, and a repeat's drawing places rows, so lists, grids and bentos are one rule.        | `repeat=<area> <per line>` in the head.      |
| A form is the same call twice, so each call has one shape.                                                  | A `form` word.                               |
| One `main=` names what stands for a spot, so moving a block changes nothing.                               | The first `text`, `gauge` or `switch` of the output, and `grid.tray=`. |
| One `icon` key, whose value says what the picture is.                                                      | `symbol`, `file`, `image` and `glyph`.       |
| A look only draws a box, and a kind or a drawing says the rest.                                             | `look=large`, `look=list` and `look=section`. |
| A complex view is a `view` of the plugin in an area, so the text language stays small.                      | More words for each new look.                |

