# spots and examples — conventions

These rules hold for the core spots in `spots/` and the spots in `examples/`. A spot follows the contract in
[PROTOCOL.md](../PROTOCOL.md), not the rules of the app's code in [AGENTS.md](../AGENTS.md).

## Rules

- A spot folder describes each of its spots in its `spot.toml`, as [spot.toml](../docs/reference/spot-toml.md) shows.
  A script holds no header.
- A spot may hold comments.
- A spot keeps its state in `OPENSPOT_DATA`. A folder from `mktemp` that the spot removes is not state.
- A core spot does no work all day: it reads on an event, never on a clock. An example may poll, and its readme
  says so.
- A spot's view moves only while `spot.isShown` is true, with SwiftUI's own motion or a moving piece that Openspot
  gives it, such as `spot.media`. [Drawing](../AGENTS.md#drawing) says what each frame may cost.
- The action that adds to a spot's list is its first item, pinned to the top, with
  [`pin=top`](../docs/reference/blocks.md#items).
- A spot's own app, such as the board of Draw, keeps its own motion. The curves of `app/Shell/Surface/SpotMotion.swift`
  are for the panel.

## The app's own words

The spots of `spots/openspot.spot/` are parts of the app, such as Settings and New spot, and take a few words that no
other spot gets. In any other spot, `edits`, `starts`, `shown` and the keys of an action below are unknown keys, except `offers = ["attachments"]`,
`account` is removed from its uses, and the variables are absent. `builtin` names these spots to the others.

```toml
title = "New spot"
edits = "spots"
```

| Word                    | Where       | Does                                                                                           |
| ----------------------- | ----------- | ---------------------------------------------------------------------------------------------- |
| `edits`                 | `spot.toml` | `edits = "spots"`: its sheet is also the Edit sheet of each spot. |
| `starts`                | `spot.toml` | `starts = "first-launch"`: its sheet opens in place of the grid when Openspot first starts.    |
| `offers`                | an action   | `offers = ["attachments"]` is open to every spot; [spot.toml](../docs/reference/spot-toml.md) says what it does. `offers = ["actions"]`: the action shows in the ⌘K menu of every card, under the spot's name, and a press calls its handler with the card's id as `item`. Origins after a space, such as `["actions mine, core"]`, fit only the cards of the person's spots (`mine`), of the spots that come with Openspot (`core`), or of the app (`builtin`). An action `<offered id>.<name>`, such as `[actions."icon.draw"]`, shows in its submenu. |
| `when`                  | an action   | In a JavaScript spot, the name of a function that gets the card's spot id and its origin, and returns whether the offered action shows. The ⌘K menu waits 2 ms for it. |
| `shortcut`              | an action   | The standard key of an offered action, as a button's `shortcut`.                               |
| `close`                 | an action   | `close = false` keeps the panel open after the action runs.                                    |
| `account`               | `uses`      | It may reach the account key; [The account](../TRUST.md#the-account) says how.          |
| `shown`                 | the root    | `shown=true` puts the spot's card on the grid, and `shown=false` takes it off.                 |
| `OPENSPOT_CONFIG`       | a variable  | The folder of the config.                                                                      |
| `OPENSPOT_SPOTS`        | a variable  | The spots folder, when it isn't `spots` in the config folder.                                  |
| `OPENSPOT_EDIT`         | a variable  | In the Edit sheet: the id of the spot it changes.                                              |
| `OPENSPOT_EDIT_FILE`    | a variable  | In the Edit sheet: the file of that spot.                                                      |
| `OPENSPOT_EDIT_FAILURE` | a variable  | In the Edit sheet: the last failure of that spot.                                              |

The spots of the app share one folder. `[scripts.<name>]` in its `spot.toml` describes the script `<name>`, with the
keys and tables of the top level under it, such as `[scripts.snooze.actions.pick]`, and its id is `openspot/<name>`.

## Checks

`make verify` runs `scripts/check-spots.sh`. It fails on a core spot with `every` in its `[on]`, and on a spot that names
`TMPDIR` or `/tmp` outside `mktemp`. `scripts/breaks/spot-clocks.txt` and `scripts/breaks/spot-state.txt` list
today's breaks. The comment and motion checks scan only `app/` and `scripts/`.

A spot's tests of its own code live in its `tests` folder, with a `run.sh` that builds and runs them. `make verify` runs
each one through `scripts/spot-tests.sh`. A test that drives a spot through Openspot stays in `app/Tests`. The `tests`
folder is not part of the spot: the app's copy of the spots and a share leave it out.
