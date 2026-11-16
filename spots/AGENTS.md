# spots and examples — conventions

These rules hold for the core spots in `spots/` and the spots in `examples/`. A spot follows the contract in
[PROTOCOL.md](../PROTOCOL.md), not the rules of the app's code in [AGENTS.md](../AGENTS.md).

## Rules

- A spot opens with its header, as [The header](../PROTOCOL.md#the-header) shows. `openspot check spots` reports a spot
  with no header.
- A spot may hold comments.
- A spot keeps its state in `OPENSPOT_DATA`. A folder from `mktemp` that the spot removes is not state.
- A core spot does no work all day: it reads on an event, never on a clock. An example may poll, and its readme
  says so.
- A spot's own app, such as the board of Draw, keeps its own motion. The curves of `app/Shell/Surface/SpotMotion.swift`
  are for the panel.

## Checks

`make verify` runs `scripts/check-spots.sh`. It fails on a core spot with `on=clock.`, and on a spot that names
`TMPDIR` or `/tmp` outside `mktemp`. `scripts/breaks/spot-clocks.txt` and `scripts/breaks/spot-state.txt` list
today's breaks. The comment and motion checks scan only `app/` and `scripts/`.

A spot's tests of its own code live in its `tests` folder, with a `run.sh` that builds and runs them. `make verify` runs
each one through `scripts/spot-tests.sh`. A test that drives a spot through Openspot stays in `app/Tests`. The `tests`
folder is not part of the spot: the app's copy of the spots and a share leave it out.
