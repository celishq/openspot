# openspot — repo conventions

## Layout

- `app/` is the Mac app, built with XcodeGen from `app/project.yml`. Run `xcodegen generate` in `app/` after you
  add or move a file. Targets:
  - `Core/` — the plugin contract and loading. Imports Foundation only.
  - `Shell/` — the menu bar app, the panel and the hotkey. Imports AppKit and SwiftUI.
  - `StandIn/` — a small program for tests: a capability that needs no Mac feature. It does not ship.
  - `Tests/` — XCTest, through `@testable import OpenspotCore`.
- `app/Keywords/` holds the CLDR keywords of emoji and symbols, one xz file per language. `scripts/emoji-keywords.py` writes
  it from a pinned CLDR version, and the build copies it into the app.
- `app/Help/` holds the guide of each `openspot` noun that has one, which `openspot help <noun>` prints. The build copies it
  into the app.
- `plugins/` holds the source of the core spots. The build copies it into the app, and they run from there.
  `plugins/openspot/` holds the spots of the app itself, such as Settings, which are always on and use only the `openspot`
  API. No code outside that folder names one of them.
- `examples/` holds plugins that show a feature, such as a view. The app does not ship them, and a test checks them.
  `make examples` copies them into the plugins of a Debug build.
- `plans/` holds design plans. It is git-ignored.
- `.temp/` holds throwaway mock-ups and screenshots. It is git-ignored.
- `.temp/openspot/` holds the plugins and the config of a Debug build, so that it never changes `plugins/` or
  `~/.config/openspot`. The build fills it once from `plugins/`, and `make dev-state` resets it. `make dev-state EMPTY=1` leaves it empty, so that the core spots run from the app, as on a new Mac.

## Writing

- Say it once, in the fewest words that keep the meaning. Short sentences, never fragments.
- A name is a noun for what a thing is. No `-er`/`-or` suffix (`Manager`, `Handler`, `Renderer`).
- One primary type per file. The filename matches it.
- Nouns own their data. Verbs are methods on the noun that owns the data.
- A toast or a failure line follows "Messages" in `PROTOCOL.md`.

## Docs

Write a doc that people read, such as `GUIDE.md` and `PROTOCOL.md`, the way Apple writes its developer docs.

- Open each page or section with one sentence that says what the thing is for and when to use it.
- Show it next, with an example and what it gives on screen. The rules come after the example.
- Order a guide by the tasks of its reader, such as "Show a number on a card", not by how the code parses it.
- Bring in a new word where the reader first needs it, with its meaning in the same sentence.
- Keep the main idea and the edge cases apart. Put limits, errors and rare cases in a short note or in the reference.
- Write natural English: "you" for the reader, short sentences, common words. Contractions are fine.
- Use one word for each meaning on the page.
- Put each rule in one place, and link to it from other places.

## Docstrings

- Docstrings on types and members only. No inline comments.
- A docstring says what the item does. Five lines on a type, three on a member, none where the name says it.

## Core and Shell

- `Core/` imports neither AppKit nor SwiftUI. `make verify` runs `scripts/check-core.sh`, which fails when it does.
- Logic that a window needs goes in `Core/`. Only drawing and window handling go in `Shell/`.
- Each colour, strength and blur radius of the panel is in `Shell/Surface/SpotTheme.swift`, and a new theme is one more value there.

## Motion

A frame has 8.3 ms at 120 Hz. During a motion, the main thread uses no more than 4 ms of each frame, the frame of the press
too. `make perf` checks it: p99 must stay under 8.3 ms.

- Move a view with FLIP: lay it out at its last place, then animate only `offset`, `scaleEffect` and `opacity` from its
  first place. Do not animate a frame, a padding, a font or a text width.
- Grow a surface with an animated shape that clips its content, masks its blur and places its rim. Do not scale a surface
  that has corners, a rim or words.
- Change words by a crossfade of two laid-out copies, not by a reflow.
- Draw blur from one fixed view behind the moving shapes. Do not put an AppKit view in a view that moves or resizes.
- The model starts a motion, not a view: no `onChange` chain, and no state written from `onGeometryChange` during a motion.
  A view that is just built lies at its first place for one turn, and its motion starts on the next turn. SwiftUI animates
  a view by the first change it sees in an update, so the animated change goes first, or alone.
- Hide a view that comes back with a mask or with opacity 0.001, not with opacity 0, which drops its drawing.

## Tests

- A test proves behaviour through the public surface: inputs in, outputs out.
- Fakes stand in only at I/O: the disk, the process, the clock.
- Write the failing test first, then the code that passes it.
- Write a script for a test with `writeScript(to:)`. macOS checks a new executable file on its first run, for 150 ms or more.
- Give a test a short pause through a setting, such as `stopPause`, and keep one test of the real time.
- Wait for a fact, never for a pause. To prove that a stopped thing does nothing more, give its action a long delay, stop it,
  wait for its end, then check.
- A time limit in a test catches a hang or a slow algorithm, not a slow Mac. Give it ten times the normal time or more.
- A test is independent. It writes only in its own folder, ends each process that it starts before it returns, and passes
  alone, in any order and beside any other test class.
- A test is the same on each Mac. It reads no state of the person, such as the home folder, the clipboard or a record in
  `TMPDIR`, no installed app, and no system data whose content changes with macOS. A fake on the `PATH` stands in for a
  tool that changes the Mac, such as `caffeinate` or `system_profiler`.
- `make verify` runs `scripts/check-tests.sh`, which fails on a test that reads the real home or the clipboard, or that
  blocks its thread with a sleep.

## Verify

```sh
make verify                # the Core and Tests checks, then the XCTest suite, with test classes in parallel
make test T=SpotRunsTests  # one test class, while you work on it
make perf N=3              # times a sheet that opens and closes 20 times, 3 runs; fails over the dropped-frame budget
make eval-agent N=1        # gives N tasks to claude -p with only `openspot guide`, and checks each spot; it costs money
```

`make verify` runs `xcodegen generate` first, so the project file matches the folders on disk.

Run `make perf` after a change to a view that moves, and compare it with the commit before by interleaved runs: the Mac's
load moves the numbers more than most changes do.

## Signing

- The team is `NNK86LQK58` (set in `app/project.yml`). Local builds use ad-hoc signing (`CODE_SIGN_IDENTITY "-"`).
- Do not commit a signing identity or a provisioning profile.

## Release

```sh
make release V=1.2.3         # verify, build, notarize, then publish a GitHub release with the DMG and the update feed
make release-build V=1.2.3   # only the signed DMG in .temp/release
```

- Release from a clean `main` that matches `origin/main`.
- The Keychain must hold the update key (Sparkle account `openspot`) and the notary login (profile `openspot`). A release
  stops and names the command for each one that is missing.
- Published apps read the feed URL and the public key, so do not change the bundle ID, the team or the key.
