# openspot — repo conventions

## Layout

- `app/` is the Mac app, built with XcodeGen from `app/project.yml`. Run `xcodegen generate` in `app/` after you
  add or move a file. Targets:
  - `Core/` — the plugin contract and loading. Imports Foundation only.
  - `Shell/` — the menu bar app, the panel and the hotkey. Imports AppKit and SwiftUI.
  - `StandIn/` — a small program for tests: a capability that needs no Mac feature. It does not ship.
  - `Tests/` — XCTest, through `@testable import OpenspotCore`.
- `plans/` holds design plans. It is git-ignored.
- `.temp/` holds throwaway mock-ups and screenshots. It is git-ignored.

## Writing

- Say it once, in the fewest words that keep the meaning. Short sentences, never fragments.
- A name is a noun for what a thing is. No `-er`/`-or` suffix (`Manager`, `Handler`, `Renderer`).
- One primary type per file. The filename matches it.
- Nouns own their data. Verbs are methods on the noun that owns the data.

## Docstrings

- Docstrings on types and members only. No inline comments.
- A docstring says what the item does. Five lines on a type, three on a member, none where the name says it.

## Core and Shell

- `Core/` imports neither AppKit nor SwiftUI. `make verify` runs `scripts/check-core.sh`, which fails when it does.
- Logic that a window needs goes in `Core/`. Only drawing and window handling go in `Shell/`.

## Tests

- A test proves behaviour through the public surface: inputs in, outputs out.
- Fakes stand in only at I/O: the disk, the process, the clock.
- Write the failing test first, then the code that passes it.
- Write a script for a test with `writeScript(to:)`. macOS checks a new executable file on its first run, for 150 ms or more.
- Give a test a short pause through a setting, such as `stopPause`, and keep one test of the real time. Wait for a fact; pause only to prove that nothing happened.

## Verify

```sh
make verify                # the Core check, then the XCTest suite, with test classes in parallel
make test T=SpotRunsTests  # one test class, while you work on it
```

`make verify` runs `xcodegen generate` first, so the project file matches the folders on disk.

## Signing

- The team is `NNK86LQK58` (set in `app/project.yml`). Local builds use ad-hoc signing (`CODE_SIGN_IDENTITY "-"`).
- Do not commit a signing identity or a provisioning profile.
