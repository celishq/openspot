# openspot — repo conventions

## Layout

- `app/` is the Mac app, built with XcodeGen from `app/project.yml`. Run `xcodegen generate` in `app/` after you
  add or move a file. Targets:
  - `Core/` — the spot contract and loading. Imports Foundation only.
  - `Shell/` — the menu bar app, the panel and the hotkey. Imports AppKit and SwiftUI.
  - `Client/` — the `openspot` command, which talks to the running app.
  - `StandIn/` — a small program for tests: a capability that needs no Mac feature. It does not ship.
  - `Tests/` — XCTest, through `@testable import OpenspotCore`.
- `app/RULES.md` holds the rules of the app that no spot author sees, by ID. Code and tests name a rule by its ID.
- `app/Keywords/` holds the CLDR keywords of emoji and symbols, one xz file per language. `scripts/emoji-keywords.py` writes
  it from a pinned CLDR version, and the build copies it into the app.
- `app/Help/` holds the guide of each `openspot` noun that has one, which `openspot help <noun>` prints. The build copies it
  into the app.
- `spots/` holds the source of the core spots, each a `<name>.spot` folder. The build copies it into the app, and they run
  from there. `spots/openspot.spot/` holds the spots of the app itself, such as Settings, which are always on and use only the `openspot`
  API. No code outside that folder names one of them.
- `examples/` holds spots that show a feature, such as a view. The app does not ship them, and a test checks them.
  `make examples` copies them into the spots of a Debug build.
- `plans/` holds design plans. It is git-ignored.
- `.temp/` holds throwaway mock-ups and screenshots. It is git-ignored.
- `.temp/openspot/` holds the spots and the config of a Debug build, so that it never changes `spots/` or
  `~/.config/openspot`. The build fills it once from `spots/`, and `make dev-state` resets it. `make dev-state EMPTY=1` leaves it empty, so that the core spots run from the app, as on a new Mac.

## Writing

- Say each thing once, in one place, and link to it from other places. Use the fewest words that keep the meaning. Short
  sentences, never fragments.
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

## Docstrings

- Docstrings on types and members only. No inline comments.
- A docstring says what the item does. Five lines on a type, three on a member, none where the name says it.

## Core and Shell

- `Core/` imports neither AppKit nor SwiftUI. `make verify` runs `scripts/check-core.sh`, which fails when it does.
- Logic that a window needs goes in `Core/`. Only drawing and window handling go in `Shell/`.
- Each colour, strength and blur radius of the panel is in `Shell/Surface/SpotTheme.swift`, and a new theme is one more value there.

## Performance

A frame has 8.3 ms at 120 Hz. Each interaction (a press, a key, an arrow, a drag, a motion) uses no more than 4 ms of the main
thread in each frame. At idle, the app wakes only for work that is due, and holds only the memory a warm panel needs. Each rule
below is one a reviewer can check in a diff.

### The press

- A press reads no disk, starts no process and asks the window server nothing. Read ahead in the background, and check only a
  cheap stamp at the press.
- The main thread never waits on a spot. The one exception: the answers to a key share one wait of 2 ms at most.
- A press makes one update. The animated change goes first in it, or alone, since SwiftUI animates a view by the first change
  it sees in an update.

### What a view reads

- A view reads only the state it shows. Move each read of a value that changes fast into the smallest child or modifier that
  shows it, behind an `if` on the fact that does not change.
- A fast signal, such as a held key, a drag or a slider, lives in its own value or in local `@State`, and reaches the model
  at its end or after a pause.
- Write an observed value only when it changes. A mutating call on an observed collection tells every reader, so guard it too.
  Mark a field that no view reads `@ObservationIgnored`.
- Store a derived value that views read, and write it where its source changes. A computed property over a list reruns on
  each read.
- A child view takes plain values, not closures, so its container skips it when nothing changed.
- A body does no pass over a list, no parse, no `stat`, no formatter or regex made anew, and no picture drawn. Do that work
  once, where the data arrives.

### Lists and search

- Fold and index each item's text once, when the list loads. A key folds only the query.
- Build each thing made from the query once per query, and pass it on.
- A list that can be long is lazy, or builds only the cells near the visible band. In a grid that is not lazy, a cell is a
  plain view with a tap and the button trait, not a `Button`.
- One drop target on a container that holds still, not one per moving item.

### Motion

Each motion is one of five kinds, each with one curve in `Shell/Surface/SpotMotion.swift`: grow (and its way back), move,
fade and press. Each duration, bounce and motion scale is in `Core/Panel/MotionTokens.swift`. A part of a surface that grows
takes its look from the surface's progress, by `SheetMorph`, and keeps no curve of its own. `make verify` runs
`scripts/check-motion.sh`, which fails on a curve written anywhere else.

- Move a view with FLIP: lay it out at its last place, then animate only `offset`, `scaleEffect` and `opacity` from its
  first place. Do not animate a frame, a padding, a font, a text width or a blur radius.
- Grow a surface with an animated shape that clips its content, masks its blur and places its rim. Do not scale a surface
  that has corners, a rim or words.
- Change words by a crossfade of two laid-out copies, not by a reflow.
- Draw blur from one fixed view behind the moving shapes. Do not put an AppKit view in a view that moves or resizes.
- The model starts a motion where its cause happens, not a view: no `onChange` chain, and no `.animation(_:value:)` on a
  container. A view that is just built lies at its first place for one turn, and its motion starts on the next turn.
- During a motion, no state is written from a measure, such as `onGeometryChange` or a scroll's geometry. Compute frames
  from the layout's own numbers, and scale the content inside a scroll view, not the scroll view.
- Content that reaches a surface during its open motion is applied when the motion ends.
- Hide a view that comes back with a mask or with opacity 0.001, not with opacity 0, which drops its drawing.

### Idle and memory

- Nothing wakes while the panel is hidden unless work is due. A sleep has a tolerance, and a write to disk waits to merge
  with others.
- A shipped spot does no work all day. A spot that polls goes in `examples/`.
- Each buffer, log and cache has a limit in bytes. A kept tail is cut back when it holds twice its limit. A loop that reads a
  stream wraps each pass in `autoreleasepool`.
- The panel stays warm while hidden. Cut the waste around it, not the panel.
- A framework that the panel does not need, such as translation or screen capture, runs in a helper process, not in the app.

### Proving a speed fix

- Choose each fix by one of these rules, and prove it with a count of the work it removes: a test through
  `withObservationTracking` that no reader is told, a count of bodies, or a bench of an optimized build. The test fails first.
- Before a rework, build a throwaway copy with the part's cost removed. Build the rework only when that copy gains more than
  two identical builds differ.
- `make perf` guards against a loss. Run it after a change to a view that moves, interleaved with the commit before and a
  copy of it, since the Mac's load moves the numbers more than most changes do. It fails when the median of dropped frames
  over 40 motions is over 140.
- A fresh reviewer reads the diff before it is called done, for rules the old code kept that the new code drops, readers
  that no longer hear of a change, and views that now run more.

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
make verify                # the Core, Tests and Motion checks, then the XCTest suite, with test classes in parallel
make test T=SpotRunsTests  # one test class, while you work on it
make perf N=3              # times a Release sheet that opens and closes 20 times, 3 runs; ACTION picks another motion
make film SPOT=caffeinate  # films the open and close of a sheet 10x slower (SLOW=1 for real speed) into .temp/film
make shots                 # saves pictures of the actions menu in the running panel into .temp/shots
make docs-images           # draws the image under each GUIDE.md example; GuideImageTests fail when one is out of date
make eval-agent N=1        # gives N tasks to claude -p with only `openspot guide`, and checks each spot; it costs money
```

`make verify` runs `xcodegen generate` before it builds, so the project file matches the folders on disk. `make perf` is
under "Proving a speed fix".

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
