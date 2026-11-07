# openspot — repo conventions

## Layout

- `app/` is the Mac app, built with XcodeGen from `app/project.yml`. Run `xcodegen generate` in `app/` after you
  add or move a file. Targets:
  - `Core/` — the plugin contract and loading. Imports Foundation only.
  - `Shell/` — the menu bar app, the panel and the hotkey. Imports AppKit and SwiftUI.
  - `StandIn/` — a small program for tests: a capability that needs no Mac feature. It does not ship.
  - `Tests/` — XCTest, through `@testable import OpenspotCore`.
- `plugins/` holds the source of the core spots. The build copies it into the app, and they run from there.
- `plans/` holds design plans. It is git-ignored.
- `.temp/` holds throwaway mock-ups and screenshots. It is git-ignored.
- `.temp/openspot/` holds the plugins and the config of a Debug build, so that it never changes `plugins/` or
  `~/.config/openspot`. The build fills it once from `plugins/`, and `make dev-state` resets it. `make dev-state EMPTY=1` leaves it empty, so that the core spots run from the app, as on a new Mac.

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
- Each colour and strength of the panel is in `Shell/SpotTheme.swift`, and a new theme is one more value there.

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

## Release

```sh
make release V=1.2.3         # verify, build, notarize, then publish a GitHub release with the DMG and the update feed
make release-build V=1.2.3   # only the signed DMG in .temp/release
```

- Release from a clean `main` that matches `origin/main`.
- The Keychain must hold the update key (Sparkle account `openspot`) and the notary login (profile `openspot`). A release
  stops and names the command for each one that is missing.
- Published apps read the feed URL and the public key, so do not change the bundle ID, the team or the key.
