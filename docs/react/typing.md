# Answer as people type

You'll build Hex. Type `0xff` in the panel's search, and a row shows 255 as you type. Type `/hex 255`, press Return,
and a message says 255 is 0xff.

## Make the spot

`hex.spot/spot.toml`:

```toml
title = "Hex"
icon = "number"

[on]
search = "^0x[0-9a-fA-F]+$"
command = ["hex"]
```

`hex.spot/hex.sh`:

```sh
#!/bin/sh
text=$(sed -n 's/^input.text=//p')
case "$1" in
  search) printf 'item=%s\ntitle=%d\ndetail=%s in decimal\n' "$text" "$text" "$text" ;;
  command)
    case "$text" in
      '' | *[!0-9]*) openspot toast "Type a number after /hex, such as /hex 255." ;;
      *) openspot toast "$text is $(printf '0x%x' "$text")" ;;
    esac
    ;;
esac
```

Press `⌃Space` and type `0xff`. A row, 255, shows at the top of the search, with 0xff in decimal under it.

## How it works

`search` is a regular expression. Each time the text in the panel's search matches it, Openspot runs `hex.sh search`
and sends the text on stdin:

```ini
input.text=0xff
```

The rows your script prints join the search's own. A newer keystroke stops the older run, so a slow answer never
shows late. A search run only shows, so it can't change the Mac.

Hex has no sheet of its own. A spot with a `search` pattern, or with an action that has a title, gets a sheet only
when `[on]` also names an event or `every`.

`command` gives your spot a slash command. People type `/hex`, and the search offers it as a row. Return runs
`hex.sh command` with the word and the rest of the line:

```ini
input.name=hex
input.text=255
```

`text` can be empty, so check it. People can rename the word in their config, and `name` is still `hex`.

If the run's first block has `type=form`, Openspot asks with a [form](../act/forms.md#ask-from-a-row). If it prints
anything else, your sheet opens and shows it. If it prints nothing, the panel closes when the run ends.

A command word starts with a letter, and holds only letters, digits, `-` and `_`.

## Put your rows in the search

`search = true` adds the rows of your `show` to the panel's search. With it, Ports from
[your first spot](../first-spot.md) finds `:3000` when you type `node`, with no regular expression and no `search`
script.

Your answers show first. `answers = "last"` at the top of `spot.toml` puts them under the others.

## The keys

| Key       | Table   | Is                                                                       |
| --------- | ------- | ------------------------------------------------------------------------ |
| `search`  | `[on]`  | `true` to add your rows, or a regular expression of the texts you answer. |
| `command` | `[on]`  | The words of your slash commands, such as `["hex"]`.                     |
| `answers` | the top | `"last"` to show your answers under the others.                          |

## Next

- [Ask for details in a form](../act/forms.md), which a slash command can open
- [Answer when the Mac changes](mac-events.md)
