# Run an action by name

You'll build Water: type `drink` in the panel, press Return, and Openspot counts one more glass. An action is
something your spot does that people run by its name, with no list to open first.

## The spot

`water.spot/spot.toml`:

```toml
title = "Water"
icon = "drop"

[actions.drink]
title = "Drink a glass"
icon = "cup.and.saucer"
inputs.glasses = { type = "number", default = 1 }
outputs.total = "number"

[actions.reset]
title = "Reset water"
icon = "arrow.counterclockwise"
confirm = "Press again to start from zero"
```

`water.spot/water.sh`:

```sh
#!/bin/sh
log="$OPENSPOT_DATA/glasses"
case "$1" in
  drink)
    sed -n 's/^input.glasses=//p' >> "$log"
    total=$(awk '{ sum += $1 } END { print sum }' "$log")
    printf 'frame=\nout.total=%s\n' "$total"
    openspot toast "Glasses: $total"
    ;;
  reset)
    rm -f "$log"
    ;;
esac
```

Type `drink` in the panel. Drink a glass shows, with its icon. Press Return, and a message says Glasses: 1.

## How it works

Each `[actions.<id>]` table is one action. Its `title` is the name people search for, and its id is the word Openspot
runs: Return on Drink a glass runs `water.sh drink`.

`inputs.glasses` is a value the action takes. Openspot sends it on stdin, as it sends a row:

```ini
input.glasses=1
```

Nobody typed a number here, so Openspot sent the `default`. Another spot, or you in the terminal, can send another:

```text
openspot spot run water drink glasses=2
```

Openspot checks each input against its type first. `glasses=two` fails, and the script doesn't run.

`outputs.total` is a value the action gives back. The script prints it as `out.total=` in its `frame=` block, so
another spot that runs Drink a glass gets the total. [Use another spot](../connect/other-spots.md) shows how.

`$OPENSPOT_DATA` is a folder Openspot gives your spot to keep its files in.

### Ask before you act

Reset water has `confirm`. The first Return shows its words, Press again to start from zero. The second Return runs
`water.sh reset`.

### Where actions show

An action with a `title` runs from the panel's search, from your spot's `⌘K` menu, and from a key people record.

Water's actions have titles, so Water has no sheet, and pressing its card runs its first action, Drink a glass. A spot
like this gets a sheet only when `[on]` names an event, `every` or `search = true`.

It also starts off the panel's grid. Add it in Edit Spots, then press `⌘` Return on its card. Its Settings list a key
for each action.

## The keys of an action

| Key              | Is                                                          |
| ---------------- | ----------------------------------------------------------- |
| `title`          | The name people run it by. With none, only a button or another spot runs it. |
| `icon`           | An SF Symbol or an emoji.                                   |
| `confirm`        | The words that ask people to press a second time.           |
| `inputs.<name>`  | A value it takes: a type, or a table with `type`, `default` and `required`. |
| `outputs.<name>` | A value it gives back, printed as `out.<name>=`.            |

An input's type is one of `text`, `number`, `bool`, `date`, `duration`, `url`, `file`, `secret` and `choice`, or a
list such as `[file]`. An action can't be named `show`, `press` or `drag`, since Openspot runs those words for other
things.

## Next

- [Ask for details in a form](forms.md) asks people for an input that has no default.
- [Use another spot](../connect/other-spots.md) runs an action of another spot.
