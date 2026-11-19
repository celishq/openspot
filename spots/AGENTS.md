# spots and examples — conventions

These rules hold for the core spots in `spots/` and the spots in `examples/`. A spot follows the contract in
[PROTOCOL.md](../PROTOCOL.md), not the rules of the app's code in [AGENTS.md](../AGENTS.md).

## Rules

- A spot folder describes each of its spots in its `spot.toml`, as [The manifest](../PROTOCOL.md#the-manifest) shows.
  A script holds no header.
- A spot may hold comments.
- A spot keeps its state in `OPENSPOT_DATA`. A folder from `mktemp` that the spot removes is not state.
- A core spot does no work all day: it reads on an event, never on a clock. An example may poll, and its readme
  says so.
- A spot's view moves only through the moving pieces that Openspot gives it, such as `spot.media`, and only while
  `spot.isShown` is true. It redraws its `body` only when a value changes, never on each frame through a
  `TimelineView` or a timer. [Drawing](../AGENTS.md#drawing) says why.
- A spot's own app, such as the board of Draw, keeps its own motion. The curves of `app/Shell/Surface/SpotMotion.swift`
  are for the panel.

## The app's own words

The spots of `spots/openspot.spot/` are parts of the app, such as Settings and New spot, and take a few words that no
other spot gets. In any other spot, `edits` and `shown` are unknown keys, `account` is removed from its uses,
and the variables are absent. `builtin` names these spots to the others.

```toml
title = "New spot"
edits = "spots"
```

| Word                    | Where       | Does                                                                                           |
| ----------------------- | ----------- | ---------------------------------------------------------------------------------------------- |
| `edits`                 | `spot.toml` | `edits = "spots"`: its sheet is also the Edit sheet of each spot.                              |
| `account`               | `uses`      | It may publish with the account key; [The account](../TRUST.md#the-account) says how.          |
| `shown`                 | the root    | `shown=true` puts the spot's card on the grid, and `shown=false` takes it off.                 |
| `builtin`               | a filter    | After `actions` in `offers`, and as the origin that `when` gets: a spot of the app.            |
| `OPENSPOT_CONFIG`       | a variable  | The folder of the config.                                                                      |
| `OPENSPOT_SPOTS`        | a variable  | The spots folder, when it isn't `spots` in the config folder.                                  |
| `OPENSPOT_EDIT`         | a variable  | In the Edit sheet: the id of the spot it changes.                                              |
| `OPENSPOT_EDIT_FILE`    | a variable  | In the Edit sheet: the file of that spot, when the person owns it.                             |
| `OPENSPOT_EDIT_FAILURE` | a variable  | In the Edit sheet: the last failure of that spot.                                              |

## Checks

`make verify` runs `scripts/check-spots.sh`. It fails on a core spot with a `clock.` event in its `spot.toml`, and on a spot that names
`TMPDIR` or `/tmp` outside `mktemp`. `scripts/breaks/spot-clocks.txt` and `scripts/breaks/spot-state.txt` list
today's breaks. The comment and motion checks scan only `app/` and `scripts/`.

A spot's tests of its own code live in its `tests` folder, with a `run.sh` that builds and runs them. `make verify` runs
each one through `scripts/spot-tests.sh`. A test that drives a spot through Openspot stays in `app/Tests`. The `tests`
folder is not part of the spot: the app's copy of the spots and a share leave it out.
