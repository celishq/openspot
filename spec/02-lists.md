# 02 Lists

`final` · Needs 01.

## Rows

A script that prints rows is a list. Each row is one block:

```text
row=Safari
detail=App
run=/Applications/Safari.app
file=/Applications/Safari.app
```

`row` and `run` are the only keys a list needs. Also use `symbol` for an SF Symbol, `file` for a file's icon, `image`
for a path to an image, or `glyph` for a short text, such as an emoji. `hides` is the ID of an action that this row does not offer. Repeat the line for each one.
`shortcut=ctrl+space` shows a key at the end of the row. A pick records the next key, and Openspot calls `<run> <key>`.

Openspot searches the rows itself and sorts recent picks first. To change this, print one block before the rows on each
read:

| Prints | Does |
|---|---|
| `search=script` | Each search change calls `<script> read <text>`. The script prints the rows that match. |
| `recents=false` | Does not sort recent picks first. |

`rank=<number>` in the header shows its rows in the main search. A lower number comes first. It needs `panel`, `launch` or a
number in its `read`. A number also needs a `key`, or Openspot refuses the plugin.

To show rows as square buttons, print `repeat=<letter> <per line>` in that block. Each button draws its picture, and the
title of the selected button shows in the sheet's header. To add parts around the rows, draw them (03). The repeated area
scrolls, and the app draws the search field over the sheet:

```text
grid=t t t t t t t
grid=a a a a a a a
repeat=a 7

part=tone
cell=t
title=Skin tone
option=none:Yellow
option=medium:Medium
value=none

row=thumbs up
run=👍
glyph=👍
```

## Actions and forms

An action is an extra thing to do. It shows in the ⌘K menu, and its key works directly. A list prints its actions with
its rows:

```text
action=copy
title=Copy
key=cmd+return
close=true
```

| Key | Meaning |
|---|---|
| `action`, `title` | Required. The call is `<script> <action> <run>`. |
| `key` | Such as `cmd+e`, `cmd+return` or `cmd+shift+d`. |
| `scope` | `command` for an action that needs no selected row. |
| `close` | `true` to close the panel after it runs. |
| `confirm` | Words that ask for a second press, such as `Press again to delete`. |
| `form` | `true` to ask for values first. |

`action=open` is special, because it sets what Enter does on a row. `title` is the word for Enter, and the default is
`Open`. `close=false` keeps the panel open after a pick.

An action with a form first runs as `<script> <action> [run]` with empty stdin. It prints a block with the title, then one
block for each field:

```text
title=New note

field=text
label=Text
type=multiline
required=true
```

A field needs `field`, its name, and `label`. `type` is `text` (the default) or `multiline`. `value` and `placeholder`
are optional. After the person fills the form, the same call runs with the values on stdin as one block, such as
`text=one\ntwo`, and it can print the `run` value of the row to select.

## Rules

| ID | Rule |
|---|---|
| C3 | A form is the same call twice: first with empty stdin, when the script prints its fields, then with the values on stdin. |
| R6 | `search=script` sends each search change to the script as `read <text>`. Otherwise Openspot searches the rows. |
| R7 | `recents=false` does not sort recent picks first. |

## Why not

| Decision | Why | Rejected |
|---|---|---|
| A form is the same call | One call shape with no exception. | A `form` word, which is easier in shell but adds a word. |
