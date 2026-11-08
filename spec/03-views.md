# 03 Views

`draft` `optional` · Needs 01 and 02.

```text
#!/bin/sh
# title=Cups today
# read=panel
# view=cups.swift
printf 'view=cups\ntitle=3\npoint=1\npoint=0\npoint=2\n'
```

```swift
import SwiftUI

struct SpotView: View {
    let spot: SpotInput

    var body: some View {
        VStack(alignment: .leading) {
            Text(spot["title"] ?? "–").font(.largeTitle.bold())
            Text("\(spot.all("point").count) days").foregroundStyle(.secondary)
        }
    }
}
```

`view=<file>` in the header names a SwiftUI view, and a `view=<id>` component (02) draws it in the area of that id (V1). The script and its view lie in a
folder of their own, such as `cups/cups.sh` and `cups/cups.swift` (F10). The path starts at the folder of the script, and
the file ends in `.swift`. The file is not executable, so it is not a spot of its own.

## The view

The file declares `struct SpotView: View` with `let spot: SpotInput`, and it has no top-level code. Openspot gives
`SpotInput`:

| Member             | Gives                                                             |
| ------------------ | ----------------------------------------------------------------- |
| `spot["key"]`      | The last value of a key in the view's own block, or nil.          |
| `spot.all("key")`  | Each value of a key, in order, for a key that repeats.            |
| `spot.size`        | The size of its area, or of the whole card.                       |
| `spot.inset`       | The space that other cards keep between their edge and words.     |
| `spot.corner`      | The corner radius of the card.                                    |
| `spot.ink`         | The colour of words, which follows light and dark.                |
| `spot.secondary`   | The opacity of a second line, such as a detail.                   |
| `spot.accent`      | The accent colour.                                                |
| `spot.font`        | The fonts of the cards: `title`, `detail`, `metric` and `value`.  |

The view fills its area of a card drawing, such as `grid.large=cups cups chart chart`, or of a sheet drawing, and with no
card drawing it fills the whole card and is clipped to the card's shape (V3). In a sheet, its lines share the free height,
as a graph's do. Put `.padding(spot.inset)` on words so that they line up with other
cards. The area's size comes from the drawing, the card's `size` and the person, and the view cannot change it. The view
gets the keys of its own block in each frame, and a frame that does not print it keeps the last ones (V4). A new frame
draws the same view again, so its `@State` stays.

The view only draws. A press on the card works as on any card (V5).

## The build

Openspot compiles the view when its card first shows, never at a scan, and again when the file changes (V6). This needs
the Command Line Tools. A view that does not compile shows the first error in its card, and `openspot check` prints it.

A shared spot carries the compiled view beside its source as `<name>.view`, for both kinds of Mac, and Openspot uses it in
place of the source (V7).

The view runs inside Openspot. A crash in it quits Openspot, and a slow `body` slows the panel. Do the work in the
script, and keep `body` to drawing what the script printed.

## Decisions

| Decision                                                                   | Rejected                                         |
| -------------------------------------------------------------------------- | ------------------------------------------------ |
| One Swift file, compiled by Openspot, with no package and no build step.   | A Swift package, or a bundle that the author builds. |
| The script holds the state, and the view draws its own block.             | A view that runs its own work or keeps its own data. |
| The view runs in Openspot's process, so it moves with the panel.           | A view in its own process, which macOS cannot place in another app's view. |
| The header names the view file, and a component places it, so a scan knows each view without a run. | A `source` key in the component, read only by a run. |

