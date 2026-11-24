# Attach what people work on

People open the panel over the app they work in. A source spot puts what they work on there, such as the front tab, in
the panel's field as a chip. People press Tab, and the panel lists each spot that takes it. Return hands it to one.

You'll build Page Title, which takes the front tab and copies its title. Browser Tab, which comes with Openspot, is the
source.

## Take a value

`page-title.spot/spot.toml`:

```toml
title = "Page Title"
icon = "textformat"
uses = ["clipboard"]

[on]
drop = ["url"]
```

`page-title.spot/page-title.sh`:

```text
#!/bin/sh
. "$OPENSPOT_SH"
case "$1" in
  drop)
    printf '%s' "$(value input.title)" | openspot clipboard copy
    openspot toast "Copied the title."
    ;;
esac
```

Turn on Browser Tab in the Attachments spot. Open the panel over Safari, press Tab, and pick Page Title. It copies the title of
the tab.

## How it takes it

`drop` takes the kinds of value your spot takes: `url`, `text`, and a file's extension, `folder` or `*`. A star takes
any file, but no `url` and no `text`. When people pick your spot, Openspot runs `drop` with the value on stdin:

```ini
input.url=https://example.com/a
input.title=Example
```

A `text` comes as `input.text`, and files as `input.file`, once for each file, as a real drop of files does. After the
run, Openspot opens your sheet when Return opens it, and closes the panel when it doesn't.

## Give a value

A source has `attachment` in its `uses`, and puts one value in the field with `openspot attachment add`. It reads in one of
two ways:

- `"attachment.pick"` takes a regular expression of the bundle ID of the front app. Its chip shows at once when the panel
  opens over a matching app, and the source runs `attachment.pick` only when Tab first picks the chip in that open of the
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

- `openspot attachment add` takes `file=` once for each file, `url=` or `text=`, with `title=`, the words of the preview,
  `app=`, the bundle ID of the app whose icon the chip shows, and `icon=`, which takes what `icon` in `spot.toml`
  takes. With none of these, it takes them on stdin, as `openspot browser tab` prints them, and adds nothing when stdin
  holds no value.
- The chip shows the value's `icon=`, else the spot's own picture when its `icon` is a file or a picture, else the icon
  of the app in front when the value is of that app, else the spot's symbol.
- `openspot browser tab`, `openspot finder selection` and `openspot text selected` read what people work on inside Openspot. A source needs
  `read` in its `uses`, and `openspot attachment add` takes what it prints. Each read but Finder's names its app by its bundle ID,
  which `attachment.pick` gets as `input.value`:

  ```text
  attachment.pick) tab=$(openspot browser tab "$(value input.value)") && printf '%s\n' "$tab" | openspot attachment add ;;
  ```

  `openspot browser tabs <bundle id>` prints each tab of each window. [Commands](../reference/commands.md) lists what each
  one prints.

- Only `openspot front app` reads which app is in front. A `panel.open` source reads it first, then the reader of that app:

  ```text
  show)
    app=$(openspot front app | sed -n 's/^app=//p')
    [ -n "$app" ] || exit 0
    { openspot text selected "$app" && echo "title=Selected text"; } | openspot attachment add
    ;;
  ```

- While `attachment.pick` runs, the field says `Reading <app>…`. When it adds nothing, the field says `Nothing to attach from
  <app>`, or the words of `openspot attachment empty <words>`. When it fails, or gives no answer in 3 seconds, the field
  shows why, such as `Openspot can't read Safari · ⏎ Allow` when `openspot browser tab` fails since Openspot may not
  read it yet. Return then opens the Attachments spot, where people allow it, and the next Tab reads again.
- A chip shows only when a spot that is on takes its kind. A source runs only when some spot takes some kind.
- A source stays off the grid and out of the search. People turn it on in the Attachments spot.

## Next

- [Use another spot](other-spots.md)
- [spot.toml](../reference/spot-toml.md)
