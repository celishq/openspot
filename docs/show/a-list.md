# A list you can press

You'll build Downloads: your ten newest downloads. Press a row to open the file, press `⌘O` to show it in Finder, or
press `⌘⌫` to move it to the Trash and keep the list open.

## The spot

`downloads.spot/spot.toml`:

```toml
title = "Downloads"
icon = "arrow.down.circle"
```

`downloads.spot/downloads.sh`:

```sh
#!/bin/sh
case "$1" in
  show)
    cd "$HOME/Downloads" || exit 0
    ls -t | head -n 10 | while read -r name; do
      printf 'item=%s\ntitle=%s\ndetail=%s\nicon=doc\npath=%s\n\n' \
        "$name" "$name" "$(stat -f %Sm -t '%b %e' "$name")" "$PWD/$name"
    done
    printf 'button=reveal\ntitle=Show in Finder\nicon=folder\nshortcut=cmd+o\n\n'
    printf 'button=trash\ntitle=Move to Trash\nicon=trash\nshortcut=cmd+backspace\nclose=false\n'
    ;;
  press)
    open "$(sed -n 's/^input.item.path=//p')"
    ;;
  reveal)
    open -R "$(sed -n 's/^input.item.path=//p')"
    ;;
  trash)
    mv "$(sed -n 's/^input.item.path=//p')" "$HOME/.Trash/"
    ;;
esac
```

Open Downloads, and you see a row for each file, with the day you got it under its name. Type to search the rows.

## How it works

`show` prints one block for each row:

```ini
item=Report.pdf
title=Report.pdf
detail=Nov 22
icon=doc
path=/Users/you/Downloads/Report.pdf
```

`path` isn't a key Openspot knows, so it's the row's own. Openspot keeps it and sends it back when you press the row:

```ini
input.item=Report.pdf
input.item.path=/Users/you/Downloads/Report.pdf
```

That way the script doesn't have to look the file up again. Add as many keys of your own as you need.

A file name is data, and data can hold a new line that would break the block. [Lines](../reference/blocks.md#lines)
shows how to print any value safely.

### Buttons on a row

A `button` block is something you do to the selected row. Its id is the word Openspot runs: press `⌘O` and Openspot
runs `downloads.sh reveal`, with the same lines on stdin as a press.

Each button shows in the row's `⌘K` menu, with its `title` and its `shortcut`. Return is always `press`.

### Close or stay

After a press, the panel closes at once, while your script runs. That's right for Open and Show in Finder, since you
leave for another app. If the script fails, a toast says why. If it prints a form, the panel opens again at the form.

Move to Trash has `close=false`, so the panel stays open. Openspot runs `downloads.sh show` again, and the file is
gone from the list.

### The keys of a row

| Key      | Is                                                              |
| -------- | --------------------------------------------------------------- |
| `item`   | The row's id, which comes back as `input.item`.                 |
| `title`  | The first line, the id if you leave it out.                     |
| `detail` | The line under the title.                                       |
| `icon`   | An SF Symbol or an emoji.                                       |
| `tone`   | A dot on the icon: `good`, `warn` or `bad`.                     |
| `close`  | `false` keeps the panel open after a press.                     |
| any other | The row's own, which comes back as `input.item.<key>`.         |

## Open another list

A row can open a list of its own, such as the days of one month. Name the pages your spot has in `spot.toml`, and give
the row a `route`: the page it opens.

`fruit.spot/spot.toml`:

```toml
title = "Fruit"
icon = "leaf"
pages = ["*"]
```

`fruit.spot/fruit.sh`:

```sh
#!/bin/sh
route=$(sed -n 's/^input.route=//p')
case "$route" in
  '') printf 'item=apple\ntitle=Apple\nroute=apple\n\nitem=pear\ntitle=Pear\nroute=pear\n' ;;
  apple) printf 'item=color\ntitle=Color\ndetail=Red\n' ;;
  pear) printf 'item=color\ntitle=Color\ndetail=Green\n' ;;
esac
```

Press Apple, and a new list slides in with one row: Color, Red. Press `⌘[` to go back.

Openspot runs `fruit.sh show` for each page, with the page on stdin as `input.route`. The first list has no route.
`pages = ["*"]` lets the spot open any route, since `*` stands for any text.

## Next

- [Lay out a sheet](a-layout.md) puts other things around the list.
- [Run an action by name](../act/actions.md) runs a button from the panel's search.
