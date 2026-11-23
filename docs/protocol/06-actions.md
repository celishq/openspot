# Actions

`draft` `optional` · Builds on [01](01-spot.md)

Use this when your spot does a thing that the person runs by name, such as adding a note or moving a window, or that a
timer or another spot runs. An action is a thing your spot can do, with typed inputs and outputs, and a table `[actions.<id>]` declares
each one.

```toml
title = "Quick note"

[actions.add]
title = "Add note"
inputs.note = { type = "text", required = true, description = "What to note" }
```

```sh
#!/bin/sh
. "$OPENSPOT_SH"
case "$1" in
  add)
    printf '%s\n' "$(value note)" >> "${OPENSPOT_DATA}/notes"
    openspot toast Saved
    ;;
esac
```

Return on Quick note opens a form with one field, Note. Return there calls `add` with `input.note=` the words, and a
toast says Saved.

## [actions.<id>]

| Key              | Type              | Is                                                    |
| ---------------- | ----------------- | ----------------------------------------------------- |
| `title`          | text              | The words that the person runs the action by.         |
| `icon`           | text              | The icon of the action.                               |
| `confirm`        | text              | The words that ask the person to press a second time. |
| `inputs.<name>`  | a type or a table | A value that the call takes; see [An input](#an-input). |
| `outputs.<name>` | a type or a table | A value that the action gives back.                   |

- A run calls `<spot> <action>`, the handler of its id, with its inputs on stdin. Openspot checks each input and fills
  its default first. A press of a block with the action's id calls it too, with `item` or `value`.
- An action with a `title` runs from the panel's search, the ⌘K menu and a key that the person records in its
  Settings. An action with no `title` runs only from a button, a view, a timer or another spot.
- When a required input is empty, Openspot asks for it with a form. A `bool` is a switch, a `choice` a menu, and any
  other type a field.
- The action gives its values as `out.<name>=` lines in its frame's [root](01-spot.md#the-root), once for each value.
- A spot whose actions have titles, and that has no `[on]`, has no sheet: Return runs its first action.
- An action MUST NOT be named `show`, `press` or `drag`.
- `openspot spot actions [id]` prints each action with its inputs and outputs.

## Types

Each input, output, [setting](07-settings.md) and value of an [event](10-other-spots.md#eventsname) has a type.

| Type       | Value                                                               |
| ---------- | ------------------------------------------------------------------- |
| `text`     | Any text.                                                           |
| `number`   | A number, such as `4` or `2.5`.                                     |
| `bool`     | `true` or `false`.                                                  |
| `date`     | An ISO 8601 day or time, such as `2026-11-22T09:00:00Z`.            |
| `duration` | A number of seconds.                                                |
| `url`      | A web address.                                                      |
| `file`     | A path that starts with `/`.                                        |
| `secret`   | A text of 8 characters or more, kept in the Keychain.               |
| `choice`   | One of its `options`.                                               |
| `[<type>]` | A list of values of that type, such as `[file]`, one line for each. |

## An input

An input takes a type alone, such as `url = "url"`, or a table:

```toml
[actions.wake]
inputs.url = { type = "url", required = true, description = "The tab to open again" }
```

| Key           | Type     | Default  | Is                                                        |
| ------------- | -------- | -------- | --------------------------------------------------------- |
| `type`        | text     | required | The type of the value.                                    |
| `required`    | bool     | `false`  | Whether the value must not be empty.                      |
| `default`     | its type | none     | The value that a call gets when it's given none.          |
| `description` | text     | none     | What the value is, which a form shows as its placeholder. |
| `options`     | [text]   | none     | The values that a `choice` offers.                        |

A list type takes no `default`.

## Forms

A form is a frame that asks the person for values, and sends them back to the handler that printed it.

```ini
frame=
type=form
title=Rename

field=name
title=Name
value=Home
```

- A form's root has `type=form` and a `title`, with a [`field`, `choice` or `switch`](03-blocks.md#inputs) for each
  value.
- Its values come back as `input.<id>=` to the same handler, with the item as `item`.
- A handler that answers a form with `error=<message>` keeps it open with the message.
