# openspot spot stats

`draft` · `openspot guide stats` prints this page. Openspot counts what each spot cost and used, so that you can see
it, and `openspot spot stats` prints the counts.

```sh
openspot spot stats --days 7
```

It prints an item, an `item=<id>` block, for each spot, the most CPU first, then a `use=<n>` block for each call that
needs a use, the newest first, then a `search=<text>` block for each search that found nothing. `--json` prints the
days.

- Openspot keeps one file for each day, for 90 days. Today's numbers are live.
- An act is something the user did with a spot: they opened its sheet, picked a row, pressed, set or toggled
  something, or ran one of its actions. A show is never an act, and acts on one spot within 2 seconds count as one.
- `--days N` adds up the last N days. `--spot <id>` shows one spot.
- `--by version` prints a row for each version of a spot, the oldest first, so you can compare a spot before and after
  a change. A version is a short hash that changes each time a file of the spot is written, replaced or touched. The
  version `-` holds the counts with no known version, such as those kept before versions, and sorts first.
- `--openmetrics` prints each counter as [OpenMetrics](https://openmetrics.io) text, labelled by `spot`, and by
  `version` with `--by version`, so that any tool for metrics can read it.

| Item key             | Meaning                                                               |
| -------------------- | --------------------------------------------------------------------- |
| `title`, `detail`    | The name of the spot, and its numbers in words.                       |
| `version`, `since`   | With `--by version`, the version of the item, and when it was first counted. |
| `runs`, `failures`   | The calls that ended, and those that failed.                          |
| `cpu`, `seconds`     | The CPU seconds of its processes, and the wall time of its calls.     |
| `read`, `written`    | The bytes its processes read and wrote.                               |
| `wakeups`            | The times its processes woke the CPU.                                 |
| `acts`, `last`       | The user's acts, and the time of the last one.                      |
| `days`               | The acts of each day, oldest first. `-` for a day with no count.      |
| `reads.<reason>`     | The shows for one reason, such as `reads.sheet.open=3` or `reads.clock=40`. |
| `hidden.cpu`, `hidden.wakeups` | The part of `cpu` and `wakeups` spent while the panel was hidden. |
| `p50`, `p95`         | The seconds within which half, and 95 in 100, of its shows and searches first answered. |
| `memory`             | The most memory its own process held at once, in bytes, not counting the processes it starts. |
| `seen`               | The days that hold a count of the spot.                               |
| `runs.by.<id>`       | The part of `runs` that the spot `<id>` started with `openspot spot run`. |
| `ran.<id>`           | The runs of the spot `<id>` that this spot started with `openspot spot run`. |
| `failures.<kind>`    | The failures of one kind: `timeout`, `exit` or `output`.              |
| `failed`             | The time of its last failure.                                         |
| `call.<noun>.<verb>` | The count of one call that needs a use, such as `call.screen.shot=2`. |
| `network`            | `declared` when its manifest names `network`.                         |
| `bodies`, `body`     | The runs of the `body` of its `SpotView`, and their seconds in all. It doesn't time the bodies of the views inside it, which SwiftUI runs later. |
| `fault`, `tone`      | Its last error, with `tone=bad`.                                      |

- A `search` block holds a search of the panel that found nothing, folded to lower case, and its `count`. A search of
  3 letters or more counts when you clear it or hide the panel with no pick, by the longest text that found nothing.
  A day keeps 50.
- A `use` block holds `time`, `spot`, `call`, such as `app.quit`, and `declared`. Only a call that the manifest doesn't
  declare is logged, so `declared` is `false`; `call.<noun>.<verb>` counts each call.
