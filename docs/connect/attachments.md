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

A source has `attachment` in its `uses`. It runs `show` each time the panel opens, and calls `openspot attachment add` with one
value. Give `panel.open` a regular expression, and the source runs only when the bundle ID of the front app matches.

`clock-tab.spot/spot.toml`:

```toml
title = "Clock Tab"
uses = ["attachment"]

[on]
"panel.open" = "^com\\.apple\\.clock$"
```

`clock-tab.spot/clock-tab.sh`:

```text
#!/bin/sh
case "$1" in
  show) openspot attachment add text="$(date +%H:%M)" title="The time" app=com.apple.clock ;;
esac
```

- `openspot attachment add` takes `file=` once for each file, `url=` or `text=`, with `title=`, the words of the preview,
  and `app=`, the bundle ID of the app whose icon the chip shows.
- A source that names an app in `panel.open` shows its chip at once, with a spinner, and fills it when it answers.
  Another source's chip shows only when it answers.
- A chip shows only when a spot that is on takes its kind. A source runs only when some spot takes some kind.
- A source stays off the grid and out of the search. People turn it on in the Attachments spot.

## Next

- [Use another spot](other-spots.md)
- [spot.toml](../reference/spot-toml.md)
