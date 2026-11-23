# Keep a copy that goes old

You'll build Quote, which answers `quote` in the panel's search with a line it keeps for a day. The first search shows
Getting a quote, and the line takes its place as soon as it comes.

## Make the spot

`quote.spot/spot.toml`:

```toml
title = "Quote"
icon = "quote.bubble"

[on]
search = "^quote$"
"cache.line" = "1d"
```

`quote.spot/quote.js`:

```text
export default {
  search(_, env) {
    const line = env.cache.get("line")
    return { item: "quote", title: line ? line.value : "Getting a quote" }
  },
  "cache.line"(_, env) {
    env.cache.set("line", "Simple is better than complex.")
  },
}
```

Type `quote`. It shows Getting a quote, then the line.

## How it works

`env.cache.get(name)` gives `{ value, age }`, with the age in seconds, or `null`. It answers at once, so a search
shows its row in the turn of the key.

`"cache.line" = "1d"` in `[on]` names the handler that fills `line`. When a read finds `line` missing, or a day old or
more, Openspot runs `cache.line` in the background, one run at a time. An age takes `s`, `m`, `h` or `d`. Nothing runs
on a clock: a cache that no one reads never fills.

`env.cache.set(name, value)` keeps the text. When the value changed, Openspot then asks your spot again for the text in
the panel's search, so the row that said Getting a quote shows the line. So set in a filler, not in `search`: a search
that sets a new value each time asks itself again and again.

A shell or Swift spot uses `openspot cache get <name>`, `openspot cache age <name>` and `openspot cache set <name>`,
which takes the value on stdin.

## What lasts

A cache sits in Openspot's caches folder and holds 16 MB for each spot. It lasts through a restart, but it is a copy:
Openspot may drop the copy it keeps in memory when the Mac runs low, and macOS may clear the folder. Keep what must
last in [your data folder](data.md).

## Next

- [Keep your own data](data.md)
- [Use the Mac](../connect/the-mac.md)
