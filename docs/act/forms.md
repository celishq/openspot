# Ask for details in a form

Some actions need a few words from you first. You'll build Notes: run Add note, fill in a short form, and the note is
saved to a file.

## The spot

`notes.spot/spot.toml`:

```toml
title = "Notes"
icon = "note.text"

[actions.add]
title = "Add note"
icon = "plus"
inputs.note = { type = "text", required = true, description = "What to note" }
inputs.list = { type = "choice", options = ["work", "home"] }
inputs.urgent = "bool"
```

`notes.spot/notes.sh`:

```sh
#!/bin/sh
case "$1" in
  add)
    input=$(cat)
    note=$(printf '%s\n' "$input" | sed -n 's/^input.note=//p')
    list=$(printf '%s\n' "$input" | sed -n 's/^input.list=//p')
    urgent=$(printf '%s\n' "$input" | sed -n 's/^input.urgent=//p')
    printf '%s\t%s\t%s\n' "$list" "$urgent" "$note" >> "$OPENSPOT_DATA/notes.tsv"
    openspot toast "Saved to $list"
    ;;
esac
```

Type `add note` in the panel and press Return. A form opens with three rows: a Note field that says What to note, a
List menu set to work, and an Urgent switch. Fill in Note and press Return, and a message says Saved to work.

## How it works

`note` is `required` and has no `default`, so Openspot can't run the action yet. It asks with a form, one row for each
input:

| Input type | Row in the form              |
| ---------- | ---------------------------- |
| `bool`     | A switch.                    |
| `choice`   | A menu of its `options`.     |
| any other  | A field to type in.          |

Each row is named after its input, and a field shows the input's `description` until you type. While Note is empty,
Return asks you to fill it in.

When you press Return, Openspot runs `notes.sh add` with every value on stdin:

```ini
input.note=Call the bank
input.list=work
input.urgent=false
```

stdin can only be read once, so the script keeps it in `input` and reads each value from there.

## Ask from a row

A form can also come from the script itself, such as Rename on a row. Print a `frame=` block with `type=form` and a
`title`, then one block for each value you need:

```ini
frame=
type=form
title=Rename

field=name
title=Name
value=Home
required=true

switch=pinned
title=Keep at the top
value=false

choice=color
title=Color
value=blue

option=blue
title=Blue

option=green
title=Green
```

The form opens with the values filled in. When you press Return, Openspot runs the same word again, with each value as
`input.<id>`, here `input.name`, `input.pinned` and `input.color`, and the row as `input.item`. To tell the two runs
apart, check whether `input.name` is there.

If a value is wrong, print `error=` and a message. The form stays open and shows it.

The form takes the place of the list. To open it as a page of its own, which slides in, give the row a `route` (see
[Open another list](../show/a-list.md#open-another-list)) and print the form when `input.route` is that page. Return
runs `press` with each value and the route as `input.route`, and Esc goes back to the list.

| Block                  | Is                                                         |
| ---------------------- | ---------------------------------------------------------- |
| `field`                | A line of text. `type=multiline` for more, `type=slider` with `min` and `max` for a number. |
| `switch`               | On or off, `true` or `false`.                              |
| `choice` and `option`  | A menu of the `option` blocks after it.                    |
| `placeholder`          | The words a field shows while it's empty.                  |
| `required`             | `true` keeps Return from sending while the field is empty. |

## Next

- [Run an action by name](actions.md) has every key of an action.
- [Settings people choose](../remember/settings.md) keeps a value from one run to the next.
