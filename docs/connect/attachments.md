# Attach what people work on

People open the panel over the app they work in. A source spot puts what they work on there, such as the front tab, in
the panel's field as a chip. People press Tab, and the panel lists each spot and action that takes it. Return hands it to one.

You'll build Page Title, which takes the front tab and copies its title. Browser Tab, which comes with Openspot, is the
source.

## Take a value

`page-title.spot/spot.toml`:

```toml
title = "Page Title"
icon = "textformat"
uses = ["clipboard"]

[actions.copy-title]
title = "Copy title"
offers = ["attachments"]
inputs.url = { type = "url", required = true }
inputs.title = "text"
```

`page-title.spot/page-title.sh`:

```text
#!/bin/sh
. "$OPENSPOT_SH"
case "$1" in
  copy-title)
    printf '%s' "$(value input.title)" | openspot clipboard copy
    openspot toast "Copied the title."
    ;;
esac
```

Open the panel over Safari, press Tab, and pick Copy title. It copies the
title of the tab.

## How it takes it

An action shows as a row under the chip when it has a `title` and one required input of the chip's kind: `url`, `text`,
or `file` or `[file]` for files. Its other inputs are optional. The row shows the action's title, with your spot's title
under it. When people pick it, Openspot runs the action with the value and the chip's title on stdin:

```ini
input.url=https://example.com/a
input.title=Example
```

`input.title` comes only when the action has a `title` input. After the run, Openspot opens your sheet when Return opens
it, and closes the panel when it doesn't.

Files also go to a spot whose [`drop`](../react/mac-events.md#take-a-dropped-file) takes each of them. Its row shows your
spot's title, with its `detail` under it, and Openspot runs `drop` with one `input.file` for each file, as a real drop
of files does.

## Offer an action

Such an action is also a command that people run from the search, the `⌘K` menu or a key. With
`offers = ["attachments"]`, it shows only for a chip. A [`pattern`](../reference/spot-toml.md#an-input) shows it only for
the values that match. Use it for an action that needs the value, such as Approve.

`review.spot/spot.toml`:

```toml
title = "Review"
icon = "checkmark.seal"

[actions.approve]
title = "Approve"
offers = ["attachments"]
confirm = "Press again to approve"
inputs.url = { type = "url", required = true, pattern = "^https://github\\.com/.+/pull/\\d+" }
inputs.title = "text"
```

`review.spot/review.sh`:

```text
#!/bin/sh
. "$OPENSPOT_SH"
case "$1" in
  approve)
    gh pr review --approve "$(value input.url)"
    openspot toast "Approved $(value input.title)."
    ;;
esac
```

Open the panel over a pull request and press Tab. Approve shows first, with Review under it. Return asks for a second
press, since the action has `confirm`. Then Openspot runs `approve` with the value and the chip's title.

The actions whose `pattern` matches come first, then the other actions, then the spots that take the files with `drop`.
A spot with an action in the list does not show again for `drop`. The list holds five rows at most.

## Give a value

A source has `attachment` in its `uses`, and puts one value in the field with `openspot attachment add`. It reads in one of
two ways:

- `"attachment.pick"` takes a regular expression of the bundle ID of the front app, or `"browsers"`, which matches each
  browser that Openspot reads, with those that people add in
  [config.toml](../../MANUAL.md#hand-what-you-work-on-to-a-spot). Its chip shows at once when the panel opens over a
  matching app, and the source runs `attachment.pick` only when Tab first picks the chip in that open of the
  panel. Use it for a read that is slow or that asks the app, such as its front tab.
- `panel.open = true` runs `show` each time the panel opens, and its chip shows when it adds a value. Use it for a read
  that is quick and that you want ready, such as the clipboard. A source ties itself to an app only with `"attachment.pick"`.

`clock-tab.spot/spot.toml`:

```toml
title = "Clock Tab"
uses = ["attachment"]

[on]
"attachment.pick" = "^com\\.apple\\.clock$"
```

`clock-tab.spot/clock-tab.sh`:

```text
#!/bin/sh
case "$1" in
  attachment.pick) openspot attachment add text="$(date +%H:%M)" title="The time" app=com.apple.clock ;;
esac
```

- `openspot attachment add` takes `file=` once for each file, `url=` or `text=`, with `title=`, the words of its details,
  `app=`, the bundle ID of the app whose icon the chip shows, and `icon=`, which takes what `icon` in `spot.toml`
  takes. With none of these, it takes them on stdin, as `openspot browser tab` prints them, and adds nothing when stdin
  holds no value.
- After the value, on stdin, more blocks draw its details under the field in place of its title, where a class with
  the [`details:`](../reference/classes.md#variants) prefix applies. They take `text`, `number`, `series`, `picture` and `icon` blocks and a
  first block of the frame's own keys, such as `class`, in the room of two lines. A block of any other kind fails with
  exit code 2:

  ```text
  printf 'url=%s\ntitle=%s\n\ntext=host\ntitle=%s\ndetail=%s\n' "$url" "$title" "$title" "$host" | openspot attachment add
  ```

- The chip shows the value's `icon=`, else the spot's own picture when its `icon` is a file or a picture, else the icon
  of the app in front when the value is of that app, else the spot's symbol.
- `openspot browser tab` and `openspot selection read` read what people work on inside Openspot. A source needs
  `read` in its `uses`, and `openspot attachment add` takes what it prints. Each read names its app by its bundle ID,
  which `attachment.pick` gets as `input.value`:

  ```text
  attachment.pick) tab=$(openspot browser tab "$(value input.value)") && printf '%s\n' "$tab" | openspot attachment add ;;
  ```

  `openspot browser tabs <app>` prints each tab of each window. [Commands](../reference/commands.md) lists what each
  one prints.

- Only `openspot front app` reads which app is in front. A `panel.open` source reads it first, then the reader of that app:

  ```text
  show)
    app=$(openspot front app | sed -n 's/^app=//p')
    [ -n "$app" ] || exit 0
    { openspot selection read "$app" && echo "title=Selected"; } | openspot attachment add
    ;;
  ```

- While `attachment.pick` runs, the field says `Reading <app>…`. When it adds nothing, the field says `Nothing to attach from
  <app>`. When it fails, or gives no answer in 3 seconds, the field shows why, such as `Openspot can't read Safari. Allow it in Openspot's settings.`
  when `openspot browser tab` fails since Openspot may not read it yet. The footer then offers `⏎ Allow`, and Return opens Settings at the source's page, where people allow it, and the next Tab reads again.
- A chip shows only when a spot has a row for it. A source runs only when some spot has a row for some
  kind.
- A source stays off the grid and out of the search. Its page in Settings holds a Show as attachment row, which hides or
  shows its chip, and `⌘K` on its chip opens that page. A hidden source runs no `attachment.pick` and no `show` at the open
  of the panel, and gives no chip. Its spot stays on. `openspot setting set --spot <id> attachment false` hides it, and
  `openspot setting set --spot <id> attachment true` shows it again.

## Hand on a row

A row of a list can stand for a value, as a chip does. Give it `url=`, `text=` or `file=`:

```ini
item=a
title=A page
url=https://example.com/a
```

People select the row and press Tab. The sheet closes, the value shows as your spot's chip in the field, and the list
shows each action and spot that takes it. Return hands it on with the row's title, as it does for a chip. Tab does
nothing on a row that no spot on the grid takes.

## Next

- [Use another spot](other-spots.md)
- [spot.toml](../reference/spot-toml.md)
