# openspot — repo conventions

## Layout

- `app/` is the Mac app, built with XcodeGen from `app/project.yml`. Run `xcodegen generate` in `app/` after you
  add or move a file. Targets:
  - `Core/` — the spot contract and loading. It imports no UI framework; see [Core and Shell](#core-and-shell).
  - `Shell/` — the menu bar app, the panel and the hotkey. Imports AppKit and SwiftUI.
  - `Client/` — the `openspot` command, which talks to the running app.
  - `StandIn/` — a small program for tests: a capability that needs no Mac feature. It does not ship.
  - `Views/` — `openspot-views`, which a Release build runs to compile each view of the core spots and the examples into a
    `.view`, and each Swift spot into a `.program`, beside its source, so that it runs on a Mac with no developer tools. It does not ship.
    Debug compiles each at its first use.
  - `Tests/` — XCTest, through `@testable import OpenspotCore`.
- `app/Keywords/` holds the CLDR keywords of emoji and symbols, one xz file per language. `scripts/emoji-keywords.py` writes
  it from a pinned CLDR version, and the build copies it into the app.
- `app/Help/` holds the guide of each `openspot` noun that has one, which `openspot help <noun>` prints. The build copies it
  into the app.
- `spots/` holds the source of the core spots, each a `<name>.spot` folder. The build copies it into the app, and they run
  from there. `spots/openspot.spot/` holds the spots of the app itself, such as Settings, which are always on and use only the `openspot`
  API. No code outside that folder names one of them. They run only from the app, so a change to one needs a build. [spots/AGENTS.md](spots/AGENTS.md) holds the rules of a spot and of an
  example.
- `examples/` holds spots that show a feature, such as a view. The app ships them as its built-in store, Openspot, and a
  test checks them. `make examples` copies them into the spots of a Debug build.
- `plans/` holds design plans. It is git-ignored.
- `.temp/` holds throwaway mock-ups and screenshots. It is git-ignored.
- `.temp/openspot/` holds the spots and the config of a Debug build, so that it never changes `spots/` or
  `~/.config/openspot`. The build fills it once from `spots/`, and `make dev-state` resets it. `make dev-state EMPTY=1` leaves it empty, so that the core spots run from the app, as on a new Mac.

## Writing

- Say each thing once, in one place, and link to it from other places. Use the fewest words that keep the meaning. Short
  sentences, never fragments.
- A name is a noun for what a thing is. No `-er`/`-or` suffix (`Manager`, `Handler`, `Renderer`). `scripts/check-names.sh`
  fails on a type with such a suffix.
- One primary type per file. The filename matches it. A file of extensions is named `Type+Topic.swift`.
  `scripts/check-files.sh` fails on a file that breaks this.
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
- `make verify` fails when a doc links to a file or a heading that does not exist, names a repo path or a `make` target
  that does not exist, or when code cites a protocol heading that does not exist (`DocReferenceTests`).
- It fails when PROTOCOL.md and Core disagree on a key, a block kind, a call word, an event, a place, a use, a shell
  helper or an `openspot` command (`ProtocolContractTests`). `scripts/protocol-gaps.txt` lists today's gaps, and it
  fails on a gap the list lacks and on a listed gap that is gone.
- It fails when an `sh`, `js` or `swift` example of GUIDE.md, PROTOCOL.md or `app/Help/` does not run (`DocExampleTests`).
  An example that needs a network, an account or a tool that not every Mac has goes in a `text` fence.
- The docs are `AGENTS.md`, `spots/AGENTS.md`, `GUIDE.md`, `PROTOCOL.md`, `CONTRIBUTING.md`, `README.md` and `app/Help/`. The code is the
  truth for how the app works, so no doc describes the app's code. Before you add a sentence, look for one that says it
  already, and link to it, since no check finds a repeat.

## Comments

- Code and the scripts in `scripts/` hold no comment and no docstring. A spot may; see [spots/AGENTS.md](spots/AGENTS.md). A name, a type or a test says what a comment would.
- The one exception is a `// @todo #<id>` puzzle. The header of a spot script is not a comment: it is part of the spot.
- `make verify` runs `scripts/check-comments.sh`, which fails on a comment.

## UX

Each spot follows [The keys of a spot](PROTOCOL.md#the-keys-of-a-spot): Return does its main act, `⌘` Return opens its
Settings, `⌘Y` its History, `⌘K` the menu of all acts. Openspot makes these for every spot, so a rule changes in one place.

- Settings follow the level they change. openspot's Settings hold only the app's rows. Each spot's own Settings hold its
  menu bar and fields. Its keys, Open, each command and Float, are in Keys… in its ⌘K menu, with the same Not set and
  `⌘⌫` Remove on every key row.
- A card's ⌘K menu holds the standard acts in one order, which `spots/openspot.spot/actions.js` offers to every card.
  A key that a footer already shows does not need a ⌘K menu of its own.
- Making and changing a spot both go through one form: describe it, then Copy prompt (`⌘⏎`), which flashes `✓ Copied`
  on the same black button. The prompt tells the agent to finish alone, with no question.

## Core and Shell

- `Core/` imports only Foundation, CoreGraphics, CryptoKit, CommonCrypto, JavaScriptCore, Observation, os, P256K, Security
  and Synchronization. `make verify` runs `scripts/check-core.sh`, which fails on any other import, also after an attribute
  such as `@preconcurrency`.
- Logic that a window needs goes in `Core/`. Only drawing and window handling go in `Shell/`.
- Each colour and strength of the panel is in `Shell/Surface/SpotTheme.swift`, and a new theme is one more value there.
- Glass is system glass, drawn by `spotGlass`, which wraps `glassEffect`. Each shape draws its own glass, outside a
  `GlassEffectContainer`, since a container drops an opacity after `glassEffect`, and the grid hides an open card and
  hides the panel by opacity. The grid's scroll edge is one gradient mask over the scroll view, so it cuts each card and
  its marks row by row. A fade dims the content before `glassEffect` (`spotFade`) and
  keeps the glass whole until its last third (`SpotTheme.glassStrength`), so faded glass never shows a sharp page.
  `make verify` runs `scripts/check-glass.sh`, which fails on `NSVisualEffectView` or a private Core Animation name in
  `Shell/`, outside `Shell/Surface/SpotBackdropBlur.swift`.
- A surface has one shape, a `SurfaceEdge` of Core drawn by `SpotRoundShape`, and its glass, its clip, its ring and its
  other marks take that value. A part inside it takes `inner()` of the edge it reads from `spotSurfaceEdge`. A titled
  window follows the corner that macOS gives it: its glass is a `ConcentricRectangle`. A borderless window gives its
  content view the edge of its surface (`NSWindow.take`). `make verify` runs `scripts/check-shapes.sh`, which fails on a
  `RoundedRectangle` in `Shell/` outside `Shell/Surface/SpotRoundShape.swift`.
- The soft backdrop of the panel is a progressive blur under the glass: fixed `SpotBackdropBlur` views of rising radius,
  each under a soft edge further in, so the blur grows weaker toward its edge. Each soft edge is a picture drawn once and
  laid as nine fixed pieces that only move and scale (`SpotBackdropEdge`, by `BackdropEdge` in Core), and the backdrop
  hides by opacity alone.
- A picture drawn off screen cannot hold system glass. It goes through `SpotPicture`, which turns the glass off, and the
  glass check fails on a file of `Shell/Picture` that draws one another way.

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

### Where work lives

- A getter, a computed property and a static factory read only memory. They touch no disk, start no process and change no
  state. Work that reads the disk is a method named for it, such as `read()` or `scan()`. `scripts/check-getters.sh` fails on
  a getter or a static factory that reads the disk.
- The model and the views do not read the disk. A loader, such as `KeptScan` or `ConfigFile`, reads it at a load, and the
  rest read the value it kept.
- Code starts a process only through `ScriptProcess`, which gives it a limit, a stop and the end of its group.
  `scripts/check-processes.sh` fails on another `Process()`.
- A stamp holds only what changes the result it guards. A choice that filters the result, such as which spots are on, is
  applied after the kept result, not put in the stamp.

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
`scripts/check-motion.sh`, which fails on a curve written anywhere else in `app/` or `scripts/`.

- Move a view with FLIP: lay it out at its last place, then animate only `offset`, `scaleEffect` and `opacity` from its
  first place. Do not animate a frame, a padding, a font, a text width or a blur radius.
- Grow a surface with an animated shape that clips its content and shapes its glass. Do not scale a surface that has corners,
  a rim or words.
- A fade of many glass surfaces is one layer over them. The ⌘K dim is the one exception: it fades each other card and the
  field by opacity (`SpotMenuFocus`), and `make perf ACTION=menu` guards its cost. A glass holds still during a motion it is
  not the subject of, since the system draws a glass again on each frame in which its content or its opacity changes.
- Change words by a crossfade of two laid-out copies, not by a reflow.
- Do not put an AppKit view in a view that moves or resizes.
- The model starts a motion where its cause happens, not a view: no `onChange` chain, and no `.animation(_:value:)` on a
  container. A view that is just built lies at its first place for one turn, and its motion starts on the next turn.
- During a motion, no state is written from a measure, such as `onGeometryChange` or a scroll's geometry. Compute frames
  from the layout's own numbers, and scale the content inside a scroll view, not the scroll view.
- Content that reaches a surface during its open motion is applied when the motion ends.
- Hide a view that comes back with a mask or with opacity 0.001, not with opacity 0, which drops its drawing.

### Idle and memory

- Nothing wakes while the panel is hidden unless work is due. A sleep has a tolerance, and a write to disk waits to merge
  with others.
- A shipped spot does no work all day; see [spots/AGENTS.md](spots/AGENTS.md).
- Each buffer, log and cache has a limit in bytes. A kept tail is cut back when it holds twice its limit. A loop that reads a
  stream wraps each pass in `autoreleasepool`.
- Each collection kept per call, page or frame drops an entry when the thing it tracks ends, and has a limit in count.
- The panel stays warm while hidden. Cut the waste around it, not the panel. A view that the panel hides stays built,
  except a spot's own view, which can run work of its own.
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
- Wait with `wait(_:until:)`, which fails with the name of the fact. Give a process its environment as a value, through
  `TestEnvironment`, and never change the environment of the test process.
- Build on the shared helpers: `temporaryFolder()`, `TestSpot`, `FakeHost`, and `PanelCase` for a test of the model.
- `make verify` runs `scripts/check-tests.sh`, which fails on a test that reads the real home or the clipboard, or that
  blocks its thread with a sleep, and on a new `Task.sleep` or `setenv` outside the shared helpers.

## Verify

```sh
make verify                # the checks in scripts/check-*.sh, then the XCTest suite, with test classes in parallel
make test T=SpotRunsTests  # one test class, while you work on it
make perf N=3              # times a Release sheet that opens and closes 20 times, 3 runs; ACTION picks another motion
make film SPOT=caffeinate  # films the open and close of a sheet 10x slower (SLOW=1 for real speed) into .temp/film
make shots                 # saves pictures of the actions menu in the running panel into .temp/shots; ACTION=search TEXT=/translate shoots a typed search
make docs-images           # shows each GUIDE.md example on screen, focused, and takes its image; GuideImageTests fail when one is out of date
make eval-agent N=1        # gives N tasks to claude -p with only `openspot guide`, and checks each spot; it costs money
```

`make verify` runs `xcodegen generate` before it builds, so the project file matches the folders on disk.

Each check runs from any folder and takes the repo root as its argument. A check whose rule the code does not meet yet keeps
today's breaks in `scripts/breaks/`. It fails on a new break and on a listed break that is gone, so a fix removes its line. `make perf` is
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
