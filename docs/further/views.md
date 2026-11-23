# Draw your own view

You'll build Cups this week: a bar for each day's cups of coffee, in your accent colour, with a cup that pulses, over a
list of the days. Classes can't draw bars like these, so a small SwiftUI file draws them.

## Make the folder

`cups.spot/spot.toml`:

```toml
title = "Cups this week"
icon = "chart.bar"
views = ["week.swift"]
```

`cups.spot/cups.sh`:

```sh
#!/bin/sh
case "$1" in
  show)
    printf 'frame=\nclass=gap-part\n\nweek=chart\nvalue=3\nvalue=1\nvalue=2\nclass=h-16\n\nitems=days\n\n'
    printf 'item=mon\nparent=days\ntitle=Monday\ndetail=3 cups\n\n'
    printf 'item=tue\nparent=days\ntitle=Tuesday\ndetail=1 cup\n\n'
    printf 'item=wed\nparent=days\ntitle=Wednesday\ndetail=2 cups\n'
    ;;
esac
```

`cups.spot/week.swift`:

```swift
import SwiftUI

struct SpotView: View {
    let spot: SpotInput

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            ForEach(Array(spot.all("value").enumerated()), id: \.offset) { _, cups in
                RoundedRectangle(cornerRadius: 4)
                    .fill(spot.accent)
                    .frame(width: 28, height: 16 * CGFloat(Int(cups) ?? 0))
            }
            Spacer()
            Image(systemName: "cup.and.saucer.fill")
                .symbolEffect(.pulse, isActive: spot.isShown)
        }
        .padding(spot.inset)
    }
}
```

Open the spot, and three bars and a pulsing cup show over the rows Monday, Tuesday and Wednesday.

## How it works

`views` names the file, and the file's name is a new kind of block. `week.swift` gives `week=`, so the script prints
`week=chart` where the bars go, as it would print `number=` or `text=`. The view takes `parent` and `class` like any
block, and fills the room its classes give it.

The file holds one `struct SpotView` with `let spot: SpotInput`, and no code at the top level. `spot` is how the view
reads its block and the theme. `spot.all("value")` gives each `value=` line of `week=chart`, so the script decides
what the bars show.

Openspot builds the file the first time the view shows, with Apple's Command Line Tools, and again when it changes. The
view runs inside Openspot, so a crash in it quits Openspot.

## What `spot` holds

| Member                                      | Is                                                                     |
| ------------------------------------------- | ---------------------------------------------------------------------- |
| `spot["key"]`, `spot.all("key")`            | The last value of a key of the view's block, and each value.          |
| `spot.send(value)`                          | Runs your script with the block's id, such as `cups.sh chart`, and `value` as the input `value`. |
| `spot.isShown`                              | Whether the view shows now. Move only while it's true.                 |
| `spot.close()`                              | Closes the sheet, float or window the view is in.                      |
| `spot.accent`, `spot.ink`, `spot.secondary` | The accent, the colour of words, and the opacity of a second line.     |
| `spot.inset`, `spot.corner`, `spot.font`    | The space a card keeps inside its edge, its corner, and its fonts.     |
| `spot.theme`                                | Every value of the theme, such as `spot.theme.color.good`.             |
| `spot.items`, `spot.selection`              | Each item of the frame, and the id of the selected one.                |
| `spot.media(path)`                          | A picture or a video of your spot's folder.                            |

On a card, a view only draws. In a sheet, it takes clicks and keys.

## Next

- [Lay out a sheet](../show/a-layout.md)
- [Classes](../reference/classes.md)
