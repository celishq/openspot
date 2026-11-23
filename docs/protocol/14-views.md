# Views

A view is a kind of block that a SwiftUI file of the spot draws, for a look or a motion that classes can't give.

```toml
title = "Cups this week"
icon = "chart.bar"
views = ["week.swift"]
```

```sh
#!/bin/sh
printf 'frame=\nclass=gap-part\n\nweek=chart\nvalue=3\nvalue=1\nvalue=2\nclass=h-16\n\nitems=days\n\n'
printf 'item=mon\nparent=days\ntitle=Monday\n\n'
printf 'item=tue\nparent=days\ntitle=Tuesday\n\n'
printf 'item=wed\nparent=days\ntitle=Wednesday\n'
```

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
            Button("Done") { spot.close() }
        }
        .padding(spot.inset)
    }
}
```

The sheet shows three bars in the accent colour, a pulsing cup and a Done button, over the rows Monday, Tuesday and
Wednesday.

- Each file of `views` is a kind of block, named by its file: `week.swift` gives `week=<id>`.
- The file MUST declare `struct SpotView: View` with `let spot: SpotInput`, and no top-level code.
- A view takes `parent` and `class` like any block, and fills the room that its classes give it.
- On a card, a view only draws. In a sheet, it takes clicks and keys.
- The view runs inside Openspot, so a crash quits Openspot.

| Member                                      | Is                                                                  |
| ------------------------------------------- | ------------------------------------------------------------------- |
| `spot["key"]`, `spot.all("key")`            | The last value of a key of its block, and each value.               |
| `spot.send(v)`                              | A call of the handler of the block's id, with `v` as `value`.       |
| `spot.answers`                              | A count that changes at each answer to a send.                      |
| `spot.isShown`                              | Whether its place shows now.                                        |
| `spot.close()`                              | A close of its sheet, float or window.                              |
| `spot.size`, `spot.card`                    | The size of its area, and the size name of its card, such as `wide`. |
| `spot.inset`, `spot.corner`                 | The space a card keeps inside its edge, and its corner.             |
| `spot.ink`, `spot.secondary`, `spot.accent` | The colour of words, the opacity of a second line, and the accent.  |
| `spot.font`, `spot.theme`                   | The fonts of the cards, and every value of the theme.               |
| `spot.items`, `spot.selection`              | Each item of the frame, and the id of the selected one.             |
| `spot.media(path)`                          | A picture or a video of the spot folder.                            |
| `spot.loop(...)`                            | A shape that moves in a loop, played by macOS.                      |
| `spot.tip(text)`, `spot.tipDelay`           | A tip that shows on hover, and its delay.                           |
| `spot.cornerButton`                         | The round button on the rim of a card.                              |
| `spot.card(id)`, `spot.cardSize(id)`, `spot.sheet(id)` | The card of another spot, its size, and its sheet from its `sample.sh`. |
| `spot.columnGap`, `spot.rowGap`, `spot.columns` | The gaps between cards, and how many columns a window holds.    |
| `SpotMetric(spot, value:, detail:, mark:, onFill:)` | A big number with its detail and an SF Symbol.              |

- A view that moves MUST stop while `spot.isShown` is false.
- `spot.theme` holds `color`, `space`, `radius`, `font` and `motion`, such as `spot.theme.color.good` or
  `spot.theme.radius.inner`, so a view follows the person's theme.
