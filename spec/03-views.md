# 03 Views

`draft` `optional` · Needs 01 and 02.

```text
#!/bin/sh
# name=Cups today
# read=panel
# view=cups.swift
printf 'title=3\npoint=1\npoint=0\npoint=2\n'
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

`view=<file>` in the header names a SwiftUI view that the card of the spot draws (V1). The path starts at the folder of the
script, and the file ends in `.swift`. The file is not executable, so it is not a spot of its own.

## The view

The file declares `struct SpotView: View` with `let spot: SpotInput`, and it has no top-level code (V2). Openspot gives
`SpotInput`:

| Member             | Gives                                                             |
| ------------------ | ----------------------------------------------------------------- |
| `spot["key"]`      | The last value of a key in the head of the last read, or nil.     |
| `spot.all("key")`  | Each value of a key, in order, for a key that repeats.            |
| `spot.size`        | The size of the place that the view fills.                        |

The view fills the card inside its edge, in place of the picture and the words (V3). The card's size comes from `size`
and from the person, and the view cannot change it. With `panel` in its `read`, the view gets the head of each read, and a
read with no head gives no values (V4). A new read draws the same view again, so its `@State` stays.

The view only draws. A press on the card works as on any card (V5).

## The build

Openspot compiles the view when its card first shows, never at a scan, and again when the file changes (V6). This needs
the Command Line Tools. A view that does not compile shows the first error in its card, and `openspot check` prints it.

A shared spot carries the compiled view beside its source as `<name>.view`, for both kinds of Mac, and Openspot uses it in
place of the source (V7).

The view runs inside Openspot (V8). A crash in it quits Openspot, and a slow `body` slows the panel. Do the work in the
script, and keep `body` to drawing what the script printed.

## Decisions

| Decision                                                                   | Rejected                                         |
| -------------------------------------------------------------------------- | ------------------------------------------------ |
| One Swift file, compiled by Openspot, with no package and no build step.   | A Swift package, or a bundle that the author builds. |
| The script holds the state, and the view draws the head of its read.      | A view that runs its own work or keeps its own data. |
| The view runs in Openspot's process, so it moves with the panel.           | A view in its own process, which macOS cannot place in another app's view. |
| A card draws the view, and a sheet draws only the app's parts for now.     | A view in a sheet before a view can take a press. |
