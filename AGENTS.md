# openspot — repo conventions

## Layout

- `app/` is the Mac app, built with XcodeGen from `app/project.yml`. Run `xcodegen generate` in `app/` after you
  add or move a file. Targets:
  - `Core/` — the spot contract and loading. It imports no UI framework; see [Core and Shell](#core-and-shell).
  - `Shell/` — the menu bar app, the panel and the hotkey. Imports AppKit and SwiftUI.
  - `Client/` — the `openspot` command, which talks to the running app.
  - `Shared/` — the files that both `Client/` and `Core/` compile: how the command finds the app's socket and its run's link.
  - `StandIn/` — a small program for tests: a capability that needs no Mac feature. It does not ship.
  - `Views/` — `openspot-views`, which a Release build runs to compile each view of the core spots and the examples into a
    `.view`, and each Swift spot into a `.program`, beside its source, so that it runs on a Mac with no developer tools. It does not ship.
    Debug compiles each at its first use.
  - `Tests/` — XCTest, through `@testable import OpenspotCore`.
- The Debug build is `Openspot Nightly.app`, with the program `OpenspotNightly` and the bundle id `openspot.celis.ai.dev`. Release keeps
  `Openspot`. The `openspot` command runs the program that `CFBundleExecutable` of its bundle names.
- `app/Keywords/` holds the CLDR keywords of emoji and symbols, one xz file per language. `scripts/emoji-keywords.py` writes
  it from a pinned CLDR version, and the build copies it into the app.
- `app/Themes/` holds the built-in themes, each in `<name>.theme/theme.toml`. Openspot, in `openspot.theme`, sets every choice,
  and each other built-in theme sets only the choices it changes. The build copies them into the app.
  [Change the look of Openspot](MANUAL.md#change-the-look-of-openspot) lists its keys and says how a person changes it.
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
  `~/.config/openspot`. The build fills it once from `spots/`, and `make dev-state` resets it. `make dev-state EMPTY=1` leaves it empty, so that the core spots run from the app, as on a new Mac. `make first-launch` also quits the Debug app, so its next run opens the Welcome. `make attachment-demo` adds the four attachment sources, six demo sources and a spot that shows what it is handed, so Tab in the Debug panel has chips to turn. `make toast-demo` builds the Debug app and sends it a few toasts.

## Writing

- Say each thing once, in one place, and link to it from other places. Use the fewest words that keep the meaning. Short
  sentences, never fragments.
- A name is a noun for what a thing is. No `-er`/`-or` suffix (`Manager`, `Handler`, `Renderer`). `scripts/check-names.sh`
  fails on a type with such a suffix.
- One primary type per file. The filename matches it. A file of extensions is named `Type+Topic.swift`.
  `scripts/check-files.sh` fails on a file that breaks this.
- Nouns own their data. Verbs are methods on the noun that owns the data.
- A toast or a failure line follows [Write a message](docs/reference/commands.md#write-a-message).

## Docs

`PROTOCOL.md` is the map of a spot's contract: `docs/first-spot.md` builds the first spot, a page in `docs/show`, `docs/act`, `docs/remember`, `docs/react`, `docs/connect` and `docs/further` for each goal, and `docs/reference` every key, block, class and command. `MANUAL.md` is the person's page, `app/Help/` the reference of the `openspot` commands, `TRUST.md` what Openspot shows the person about a spot, and `spots/AGENTS.md` the words of the app's own spots. No doc describes the app's code.

`make verify` checks facts, not style: a link or a cited heading that doesn't exist (`DocReferenceTests`), an `sh`, `js` or `swift` example that doesn't run (`DocExampleTests`; put one that needs a network or a rare tool in a `text` fence), a picture of a page older than its example (`GuideImageTests`), and an `openspot` command that a doc names but the command doesn't take (`DocCommandTests`).

## Comments

- Code and the scripts in `scripts/` hold no comment and no docstring. A spot may; see [spots/AGENTS.md](spots/AGENTS.md). A name, a type or a test says what a comment would.
- The one exception is a `// @todo #<id>` puzzle.
- `make verify` runs `scripts/check-comments.sh`, which fails on a comment.

## UX

Each spot follows [Use the keys of a spot](MANUAL.md#use-the-keys-of-a-spot): Return does its main action, `⌘` Return opens
its Settings, `⌘Y` its History, `⌘K` the menu of all actions. Openspot makes these for every spot, so a rule changes in one place.

- Settings follow the level they change. openspot's Settings hold only the app's rows. Each spot's own Settings hold its
  keys first, Open, each command and Float, then its fields, its menu bar and its window, with the same Not set and `⌘⌫` Remove on
  every key row.
- A card's ⌘K menu holds the standard actions in one order, which `spots/openspot.spot/actions.js` offers to every card.
  A key that a footer already shows does not need a ⌘K menu of its own.
- Making and changing a spot both go through one form: describe it, then Copy prompt (`⌘⏎`), which flashes `✓ Copied`
  on the same black button. The prompt tells the agent to finish alone, with no question.

## Core and Shell

- `Core/` imports only Foundation, CoreGraphics, CryptoKit, CommonCrypto, ImageIO, JavaScriptCore, Observation, os, P256K, Security
  and Synchronization. `make verify` runs `scripts/check-core.sh`, which fails on any other import, also after an attribute
  such as `@preconcurrency`.
- Logic that a window needs goes in `Core/`. Only drawing and window handling go in `Shell/`.
- Each size, colour, strength, font and motion value has one name in a token file: `SpotTokens` (measured base values in
  `Core/Theme/SpotTokens.swift`, formulas over them in `Core/Theme/SpotTokens+Derived.swift`, sizes of single parts in
  `Core/Theme/SpotTokens+Parts.swift`), `SpotTheme`, `SpotType` and `MotionTokens`. A theme file names only the choices of a theme, so a
  new theme is one more file. `Core/Theme/` works out every other value from them by rules anchored on the measured values
  of Openspot, and `SpotTheme`, `SpotType`, `SpotTokens` and `MotionTokens` read the result. The defaults of the rules
  mirror the choices in `app/Themes/openspot.theme/theme.toml`, which `ThemeTests` checks. A value that no theme chooses,
  such as a colour of one card, is a constant in a token file. `make verify` runs `scripts/check-tokens.sh`, which fails
  on a number or a colour written for the look in `Shell/`, outside the token files, `Shell/Picture`, `Shell/Mac` and
  `Shell/Tools`.
- Glass is system glass, drawn by `spotGlass`, which wraps `glassEffect`. Each shape draws its own glass, outside a
  `GlassEffectContainer`, since a container drops each opacity and scale after `glassEffect`, and the grid hides an open card and
  hides the panel by opacity. The grid's scroll edge is one gradient mask over the scroll view, so it cuts each card and
  its marks row by row. A fade dims the content before `glassEffect` (`spotFade`) and
  keeps the glass whole until its last third (`SpotTheme.glassStrength`), so faded glass never shows a sharp page.
  `make verify` runs `scripts/check-glass.sh`, which fails on `NSVisualEffectView` or a private Core Animation name in
  `Shell/`, outside `Shell/Surface/SpotBackdropBlur.swift`.
- Each app window opens through `SpotSheetWindow.make`, so it has the same title bar, keys and Dock presence, and
  the system material, not glass, so the glass of what it shows stands out. It ends with `SpotWindowFooter`, its hint and Done. `make verify` runs `scripts/check-windows.sh`, which fails on a window
  that `Shell/` makes elsewhere, except the panel and its parts, the screen backdrop under it, the toast, a float, the screen pick and an off-screen picture.
- A surface has one shape, a `SurfaceEdge` of Core drawn by `SpotRoundShape`, and its glass, its clip, its ring and its
  other marks take that value. A part inside it takes `inner()` of the edge it reads from `spotSurfaceEdge`. A titled
  window follows the corner that macOS gives it. A borderless window gives its
  content view the edge of its surface (`NSWindow.take`). `make verify` runs `scripts/check-shapes.sh`, which fails on a
  `RoundedRectangle` in `Shell/` outside `Shell/Surface/SpotRoundShape.swift`.
- The soft backdrop of the panel is one fade around the content, `BackdropFade` in Core: none at the outer edge of the
  halo, full at the content, and the blur full under it by `halo-inset`, so text fades out at the edge of the tiles. It shows as the system's variable blur (`SpotBackdropBlur`) or as a tint
  (`SpotBackdropTint`), both masked by the same small picture of the fade (`SpotBackdropFade`), drawn again only when
  the backdrop's resting shape changes. While a sheet moves the foot, each frame's picture is the rows of one tall picture (`BackdropFade.stretch`). The backdrop hides by opacity alone.
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
- Each entry point of a person's act runs in `asOnePress`. A source of the hint only marks it stale. The outermost press works the
  hint out once and writes it as its last change, so no setter writes the hint, and the observation's hop works it out only for a
  change that no press made. A setter must not write through `change`, since `withTransaction` can flush the pending update, and
  a body can then run between two writes that it reads together, such as `visible` and `placements`. `make verify` runs `scripts/check-presses.sh`, which fails on a `change(` inside a setter in `Core/` or in a function of the same file that the setter calls, and on a
  public `SpotsModel` method that a gesture, a button, a key or a drop closure of `Shell/` calls and that, after its guards, neither
  starts with `asOnePress` nor only calls a method that does, except the fast signals of `scripts/fast-signals.txt` (`dragSpot`,
  `resizeSpot`, `gridScrolled` and `setLevel`), which fire on each move of a drag, a slider or a scroll and so are no press.

### Where work lives

- A getter, a computed property and a static factory read only memory. They touch no disk, start no process and change no
  state. Work that reads the disk is a method named for it, such as `read()` or `scan()`. `scripts/check-getters.sh` fails on
  a getter or a static factory that reads the disk, also by `fopen`, `fread` or `readPlist`.
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
- A fact that only a few leaf views need is read by the leaf from the model, never written into the environment of a container.
  A card reads a panel-wide fact, such as the open sheet, only when it is the selected card (`marksMenu(ofCard:)`, `focus(ofCard:)`).
- Attach a preference only where it can hold a value. A ring that cannot mark the menu carries no `SpotMenuAnchor`, and the
  selected-or-not switch lives in a leaf (`MenuMark`).
- A body does no pass over a list, no parse, no `stat`, no formatter or regex made anew, and no picture drawn. Do that work
  once, where the data arrives.

### Lists and search

- Fold and index each item's text once, when the list loads. A key folds only the query.
- Build each thing made from the query once per query, and pass it on.
- A list that can be long is lazy, or builds only the cells near the visible band. In a grid that is not lazy, a cell is a
  plain view with a tap and the button trait, not a `Button`.
- One drop target and one pointer area on a container that holds still, not one per moving item. The panel takes no
  pointer while a sheet grows or shrinks, since SwiftUI tests a still pointer against the panel on each frame in which
  content moves under it.

### Motion

Each motion is one of five kinds, each with one curve in `Shell/Surface/SpotMotion.swift`: grow (and its way back), move,
fade and press. Each duration, bounce and motion scale is in `Core/Theme/MotionTokens.swift`. A part of a surface that grows
takes its look from the surface's progress, by `SheetMorph`, and keeps no curve of its own. `Core/Motion/` holds the geometry and the clock of each motion, such as `SheetMorph`, `SheetPush` and `SheetOpening`. `make verify` runs
`scripts/check-motion.sh`, which fails on a curve written anywhere else in `app/` or `scripts/`, except the base that `SpotSpring` builds for each spring of `SpotMotion`.

- Move a view with FLIP: lay it out at its last place, then animate only `offset`, `scaleEffect` and `opacity` from its
  first place. Do not animate a frame, a padding, a font, a text width or a blur radius.
- Grow a surface with an animated shape that clips its content and shapes its glass. Do not scale a surface that has corners,
  a rim or words.
- A fade of many glass surfaces is one layer over them. The ⌘K dim is the one exception: it fades each other card and the
  field by opacity (`SpotMenuDim`), and `make perf ACTION=menu` guards its cost. A glass holds still during a motion it is
  not the subject of, since the system draws a glass again on each frame in which its content or its opacity changes.
- A glass whose shape is a rounded rectangle (`RoundedRectangle`, `SpotRoundShape`, `SpotSurfaceShape`) becomes a layer
  corner, and the system draws it once. A glass of any other shape, such as a path built by `subtracting`, is drawn again on each
  frame of a motion.
- An animatable modifier's output is constant while its view is hidden, since each frame that moves a glass works out its whole
  subtree again, and `visualEffect` does not spare that. A pushed grid card holds still once its fade has hidden it
  (`SheetPush.pose`), and takes no click.
- Change words by a crossfade of two laid-out copies, not by a reflow.
- Do not put an AppKit view in a view that moves or resizes, except a moving piece of a spot's view (see
  [Drawing](#drawing)).
- The model starts a motion where its cause happens, not a view: no `onChange` chain, and no `.animation(_:value:)` on a
  container. A view that is just built lies at its first place for one frame, and its motion starts on the next frame
  (`SpotsHost.nextFrame`), never on the next turn of the queue, which can run before that frame is drawn.
- During a motion, no state is written from a measure, such as `onGeometryChange` or a scroll's geometry. Compute frames
  from the layout's own numbers, and scale the content inside a scroll view, not the scroll view.
- Each spring ends when it looks done. `SpotSpring` runs SwiftUI's spring value for value and finishes once the travel it can
  still make is under `MotionTokens.restFraction` of its own travel, half a point over the longest travel of the panel
  (`SpringEnd`). It reports its logical end on the same frame as the plain spring, and its removal comes sooner.
- Content that reaches a surface during its open or close motion is applied when the motion ends. A close that cuts an open
  short holds the content to the close's end.
- A sheet opens and closes by one rule, whatever its source (`SheetMorph.Source`): a card in sight, or the field for any
  other sheet. The source shows its own look and words, and they fade over the first half of the motion. The sheet's
  content, its title too, fades in from `MotionTokens.contentStart`, softened by `MotionTokens.contentSoftness`, and fades
  out as the progress itself, so a close takes about 125 ms from 90% to 5% (`SheetMorph.contentOpacity(at:isOpen:)`). No part
  pops in when the shape has room for it.
- The field's glass lies uncut under the sheet's glass, drawn by a second `SpotFieldView` below the sheet. It fades once the
  sheet's moving shape holds it by a margin (`SheetMorph.fieldGlassOpacity`, `SheetMorph.clearance`), so one glass shape shows and no
  glass is cut.
- The blur's foot is the lower of the moving shape's foot and the grid's foot, which reaches the sheet's foot while the
  grid fades. The footer sits on it, and a grid card has faded by the time it reaches the card (`PanelFoot`).
- The actions menu is placed from its card's resting frame, never from the card's moving outline, and the card's focus
  grows on the menu's own grow (`isMenuGrown`).
- A sheet that opens over the actions menu folds the menu in the update that shows the sheet, and the menu's foot is
  where the sheet's footer starts. A menu row that another spot runs keeps the menu until its run ends, so whatever
  the run opens takes the menu's place in one motion.
- A step of the flow, a push, a back or a forward, is the same grow motion as a sheet that opens. Its stand-ins, the leaving page and the
  field's copy, give way to the real views when its animation is removed, so the page and the field land where they
  moved to. A press may start the next step once the step is logically complete (`SpotsHost.change(_:_:completion:removal:)`).
  A stand-in draws with the same views as what it stands in for (`SpotFieldPrompt`), so the hand-off shows no change.
- Hide a view that comes back with a mask or with opacity 0.001, not with opacity 0, which drops its drawing.

### Drawing

A view that moves on its own, such as a liquid, a clock hand or a GIF, keeps each frame within the budget of an
interaction.

- It may move with SwiftUI, such as an animation, keyframes or a `TimelineView`, or in the render server, such as a Core
  Animation animation or a video layer. Its work on the main thread stays within the 4 ms of each frame that
  [Performance](#performance) gives, so only the views that show the moving value read it.
- Live content may sit in a glass.
- A view moves only while its place shows: the panel is shown, its card is in sight, and no sheet, menu, Edit Spots or
  motion of the panel covers it. The model decides it, and a spot's view reads it as `spot.isShown`.
- Openspot gives a spot's view each moving piece it needs, such as `spot.media`, so a spot never writes AppKit. Such a
  piece is the one AppKit view that may sit in a view that moves.

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
- A test of Core builds each spot it runs, with each kind of part that the real one prints, so a change of the protocol
  never waits on a spot that has not moved. Only a test of one real spot, or a rule over every spot that ships, reads
  `spots/` or `examples/`.
- Write the failing test first, then the code that passes it.
- Write a script for a test with `writeScript(to:)`. macOS checks a new executable file on its first run, for 150 ms or more.
- Give a test a short pause through a setting, such as `stopPause`, and keep one test of the real time.
- A test of a held frame waits for the hold itself (`SheetOpening.waitingFrames`), never for a count of yields. A test of Core
  names only the rule it proves, since a Shell modifier that applies the rule is out of its reach.
- A test takes its base spring from `SpotSpring(duration:bounce:).base` and writes no curve.
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
sh scripts/pixel-diff.sh shoot before  # saves pictures of fixed screens, dark and light, into .temp/pixels/before
sh scripts/pixel-diff.sh compare before after  # counts the pixels that differ in each picture, and marks them in .temp/pixels/marks
make docs-images           # shows each example of the docs that has a picture on screen, focused, and takes its image; GuideImageTests fail when one is out of date
make eval-agent LABEL=base # gives each task of scripts/agent-eval/ to claude -p (Sonnet) N=3 times, grades what it did and how it used
                           # the command, into .temp/agent-eval/base; TASKS=calc picks tasks; it costs money
make eval-compare LABELS="base phase1"  # prints the summaries of two eval runs one after the other
```

`make verify` runs `xcodegen generate` before it builds, so the project file matches the folders on disk.

`openspot render` and `openspot check` start the Debug app of their build when it isn't running, and it keeps running
after the command ends. It runs on `.temp/openspot/` of the tree it was built from, whatever `--config` the command
took. Before you finish your work, quit each Debug app you started with that build's `openspot app quit`, with no `--config`.

Each check runs from any folder and takes the repo root as its argument. A check whose rule the code does not meet yet keeps
today's breaks in `scripts/breaks/`. It fails on a new break and on a listed break that is gone, so a fix removes its line. `make perf` is
under "Proving a speed fix".

## Signing

- The team is `NNK86LQK58` (set in `app/project.yml`). Local builds use ad-hoc signing (`CODE_SIGN_IDENTITY "-"`).
- Do not commit a signing identity or a provisioning profile.

## A local build of main

A local build puts the newest `main` on your Mac before a release holds it. Build it in a throwaway `git worktree`, so
that your own checkout stays as it is:

```sh
(cd app && xcodegen generate >/dev/null)
xcodebuild -project app/Openspot.xcodeproj -scheme Openspot -configuration Release -destination 'platform=macOS' \
  -derivedDataPath .temp/local ONLY_ACTIVE_ARCH=YES build \
  CURRENT_PROJECT_VERSION=$(git rev-list --count HEAD) \
  UPDATE_PUBLIC_KEY=$(defaults read /Applications/Openspot.app/Contents/Info SUPublicEDKey) \
  CODE_SIGN_INJECT_BASE_ENTITLEMENTS=NO
osascript -e 'quit app "Openspot"'
rm -rf /Applications/Openspot.app && ditto .temp/local/Build/Products/Release/Openspot.app /Applications/Openspot.app
open /Applications/Openspot.app
```

- `CURRENT_PROJECT_VERSION` numbers the build by its count of commits, as `make release` does. The updater then keeps it
  until a release of a later commit replaces it.
- `UPDATE_PUBLIC_KEY` takes the key of the installed release, so that the build still checks for updates.
- The build is signed ad hoc ([Signing](#signing)), so macOS may ask again for a permission that the release had.

Xcode 26.5, with Swift 6.3.2, fails on `main` in two places. Patch only the throwaway copy, never a commit, in a way that
changes nothing on macOS 26:

- `main` calls an API of the macOS 27 SDK, such as `concentricCornerRadii`, behind `if #available(macOS 27.0, *)`. Replace
  that block with its fallback, since it never runs on macOS 26.
- The compiler crashes in IR generation, on a reabstraction thunk, when a `@MainActor @Sendable` function value is passed
  as a closure, such as `Binding(get: { text }, set: onSearch)`. Pass a closure that calls it: `set: { onSearch($0) }`.

## Release

```sh
make release V=1.2.3         # verify, build, notarize, then publish a GitHub release with the DMG and the update feed
make release-build V=1.2.3   # only the signed DMG in .temp/release
```

- Release from a clean `main` that matches `origin/main`.
- The Keychain must hold the update key (Sparkle account `openspot`) and the notary login (profile `openspot`). A release
  stops and names the command for each one that is missing.
- Published apps read the feed URL and the public key, so do not change the bundle ID, the team or the key.
