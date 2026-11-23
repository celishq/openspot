# Actions and settings

An action is a thing that a spot can do, with typed inputs and outputs, and a setting is a choice of the person that the
spot keeps.

```toml
title = "Quick note"

[settings]
folder = { type = "text", title = "Folder" }

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

| Key              | Type                   | Is                                                     |
| ---------------- | ---------------------- | ------------------------------------------------------ |
| `title`          | text                   | The words that the person runs the action by.          |
| `icon`           | text                   | The icon of the action.                                |
| `confirm`        | text                   | The words that ask the person to press a second time.  |
| `inputs.<name>`  | a type or a table      | A value that the call takes; see [An input](02-spot-toml.md#an-input). |
| `outputs.<name>` | a type or a table      | A value that the action gives back.                    |

- An action with a `title` runs from the panel's search, the ⌘K menu and a key that the person records in its Settings.
  An action with no `title` runs only from a button, a view, a timer or another spot.
- A run calls the handler `<id>`, with its inputs on stdin. Openspot checks each input and fills its default first.
- An action whose required input is empty asks for it with a form. A `bool` is a switch, a `choice` a menu, and any
  other type a field.
- The action gives its values as `out.<name>=` lines in its frame's [root](04-frames.md#the-root).
- A spot whose actions have titles and that has no `[on]` has no sheet: Return runs its first action.
- An action MUST NOT be named `show`, `press` or `drag`.
- `openspot spot actions [id]` prints each action with its inputs and outputs.

## [settings]

| Key           | Type     | Is                                                     |
| ------------- | -------- | ------------------------------------------------------ |
| `type`        | text     | The [type](02-spot-toml.md#types) of the value, required. |
| `title`       | text     | The words of its row in the spot's Settings.           |
| `icon`        | text     | The icon of the setting.                               |
| `default`     | its type | The value while the person has set none.               |
| `description` | text     | What the setting is for.                               |
| `options`     | [text]   | The values that a `choice` offers.                     |

- Each call gets each setting on stdin as `setting.<name>=`.
- Openspot shows and keeps a `choice` or a `bool` itself. Return on any other setting calls the handler of its name,
  which can ask with `openspot folder pick` or a form, and keep the value with `openspot setting set <name> <value>`.
- A `secret` never comes on stdin. Read it with `openspot setting get <name>`. Openspot keeps it in the Keychain and asks
  for it in its own form.
- A setting MUST NOT be named `icon`, `enabled`, `menubar`, `open`, `float` or `key.<action>`.

## Forms

A form is a frame that asks the person for values, and sends them to the handler that printed it.

```ini
frame=
type=form
title=Rename

field=name
title=Name
value=Home
```

- A form's root has `type=form` and a `title`, with a `field`, `choice` or `switch` for each value.
- Its values come back as `input.<id>=` to the same handler, with the item as `item`.
- A handler that answers a form with `error=<message>` keeps it open with the message.
