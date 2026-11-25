# Trust in Openspot

A spot runs with your rights. This page says what Openspot shows you about a spot before you add it, what it records
after each use, and how the sandbox and signed releases limit what a spot can do.

```toml
title = "Coffee"
uses = ["app"]
```

```sh
#!/bin/sh
openspot app quit
```

Coffee names `app` in its `uses`, so its quit of Openspot is a use it declared. Openspot asks you nothing in daily use.
It shows what a spot can do when you add or update it, and shows each use after it happens. A spot gets only the uses
it declares.

## Uses

`uses` in a spot's `spot.toml` names what the spot uses. Openspot doesn't load a spot with an unknown use.

| Use         | The calls that need it                                                                                                                                          |
| ----------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `app`       | `app quit`, `app restart`, each call of `theme` but `theme list`, `update check`, `update install`, and `setting set` of `menubar`, `window`, `open`, `float`, `key.<action>` or of the spot `openspot` |
| `spots`     | `spot add`, `spot remove`, `spot allow`, `spot settings`, `spot edit`, `spot prompt`, `spot share`, `spot delete`, `spot new`, `spot run`, `spot log`, `access grant`, `setting list`, `setting set` of `enabled`, and `setting get`, `set` or `change` of another spot |
| `screen`    | `screen sources`, `screen shot`, `screen record`, `window frame`, `window move` and `color pick`                                                                |
| `clipboard` | `clipboard copy`, `clipboard paste` and `clipboard read`                                                                                                        |
| `calendar`  | each call of `calendar` and `reminders`                                                                                                                         |
| `power`     | `power lid-closed`                                                                                                                                              |
| `timer`     | each call of `timer`                                                                                                                                            |
| `attachment` | `attachment add`. A spot with it runs when the panel opens, stays off the grid, and puts a value in the panel's field.                                             |
| `read`      | `front app`, `browser tab`, `browser tabs`, `selection read`, `access list` and `access ask`. A read from `show` never asks macOS for access, and fails when Openspot doesn't have it yet.                                             |
| `network`   | No call. The spot reaches the network.                                                                                                                          |
| `files`     | No call. The spot writes outside its data folder.                                                                                                               |
| `account`   | `store publish`. Only a spot of `spots/openspot.spot` can have it; see [The account](#the-account).                                                             |

- A call that needs a use the manifest doesn't name fails. Openspot tells you once a day for each spot and use, and the
  spot shows as Needs review in Settings until you allow the use; see [Let a spot use what it was refused](#let-a-spot-use-what-it-was-refused).
  `openspot check spots` can't report such a call, because only a run shows it. `openspot spot stats` lists each one.
- Openspot knows which spot makes each call of `openspot` by the link it gives each process of the spot on file
  descriptor 11, not from the variables of the process. Each process that the spot starts inherits it, so leave fd 11
  open, and start a command from Swift with `posix_spawn`, since Foundation's `Process` closes it. An app that the spot
  opens doesn't get it, and the link ends with the spot's process. A process of the spot that closed fd 11 is still
  known by the process group that Openspot started it in, but only the link lets it run another spot with
  `openspot run` or tell other spots with `openspot emit`. A call that runs in a process of its own, such as one that
  the running app hands back, runs with the rights of the spot's process and nothing more.
- Only your own processes can reach the API.
- No other spot and no Terminal reads a secret setting. `setting get` prints `•••` for it, and `setting list` prints
  `set`. `setting set` of it fails. Only its own spot reads it, with `setting get`, and only its row in Settings changes it.
  Openspot keeps a secret in the Keychain, under the spot's id and the setting's key, never in the config, and removes
  it with the spot.

## What macOS gives Openspot

macOS gives each access, such as Screen Recording, to Openspot as a whole. Openspot passes it only to the spots whose
calls need it.

| Access            | The calls that need it                                   | The calls that may need it              |
| ----------------- | -------------------------------------------------------- | --------------------------------------- |
| Accessibility     | `clipboard paste`, `window frame` and `window move`      | `selection read`, for the selected text |
| Automation        | `browser tab` and `browser tabs`                         | `selection read`, for Finder, and `calendar show` |
| Screen Recording  | `screen shot` and `screen record start`                  |                                         |
| Calendars         | `calendar events`, `calendar calendars` and `calendar add` |                                       |
| Reminders         | `reminders due`, `reminders lists`, `reminders add` and `reminders done` |                         |
| Camera            |                                                          | `screen record start` with the camera   |
| Microphone        |                                                          | `screen record start` with the microphone |
| Input Monitoring  |                                                          | `screen record start` that records keys and clicks |
| Keep-awake helper | `power lid-closed`                                       |                                         |

A spot needs an access when a call in its files, or a call it made, needs it. An access that a call only may need is
asked for at its first use, and never stops a spot.

## Settings › Access

Settings opens at Access. It shows what macOS gives Openspot, and which spots can't run yet.

- **Needs you** lists each spot that can't run, with one grey line of what it lacks.
- **macOS gives Openspot** lists each access that a spot needs, the spots that need it, and whether macOS allows it.
  The accesses that no spot needs fold into one row.

A spot is in one of four states:

| State        | Means                                                                    |
| ------------ | ------------------------------------------------------------------------ |
| Ready        | macOS gives Openspot each access that the spot's calls need.            |
| Needs access | macOS doesn't give Openspot an access that the spot needs yet.          |
| Needs review | The spot made a call of a use that its `uses` doesn't name.             |
| Off          | You turned the spot off.                                                 |

A spot that needs access or review shows a lock on its card. A press of the card opens Settings at the spot.

To take an access away from one spot, turn the spot off. To take it from every spot, turn it off in System Settings.

## Let a spot use what it was refused

A spot that Needs access shows Allow… in Needs you. Allow… walks you through each access it lacks, one at a time, beside
System Settings. It moves on by itself when you turn the access on. Screen Recording needs Openspot to start again, so
its step offers Restart Openspot, and Settings opens again at the same step. `openspot spot allow <id>` starts the same
walk from Terminal.

A spot that Needs review shows Review… in Needs you. Review… allows the use that the spot tried, and records it in
`spots.lock`, as an update with `--yes` does. `openspot spot allow <id> <use>` does the same from Terminal.

- Only a spot that `openspot spot add` added can be allowed a use. For a spot you made, add the use to `uses` in its
  `spot.toml`.
- Only you can allow a use, in Settings or in Terminal. A spot that you added fails when it calls `openspot spot allow`.

## The review before an add

Before an add, the review shows the title, the `uses`, each spot that it binds under **Binds**, and a line **Can also**
with what the code seems to do but doesn't name: the network, `rm`, `screencapture`, `pbcopy` or `pbpaste`. It warns,
and never blocks the add. A bound spot that isn't installed and doesn't come with Openspot shows as not installed.

- The review names each file that Openspot can't show as text, such as the built program of a Swift spot or a built
  view, and says that it can do all that you can. For a built file, it says that the source beside it may not match.
  Openspot can't prove that a built file comes from its source: it only skips one whose name doesn't hold the hash of
  the source that is there now.
- So Openspot runs the program that a Swift spot carries only in two cases: the spot ships inside Openspot, or the Mac
  has no Command Line Tools, where the review has said that the program may not match its source. On a Mac with the
  tools, a spot that you added runs only what Openspot built there from the source you can read. A share never passes a
  carried program on: it builds a new one from the sources it ships.
- An update with no new use and no new binding applies quietly. An update with a new use or a new binding waits for
  `--yes`. So does an update that removes an action that another installed spot binds, or makes an input of one
  required with no default, and the review names each such spot.

## The sandbox

Each process of a spot runs in a sandbox, which holds `network` and `files` to what `uses` declares.

- A spot reaches no network unless `uses` names `network`.
- A spot writes only to its data folder and the temp folders unless `uses` names `files`. With `screen`, it can also
  write to the Desktop, Movies and the screenshots folder.
- The sandbox stops nothing else. A spot still reads your files, starts programs and sends Apple events.

## Signed releases

A spot folder can hold `releases.jsonl`, the signed releases of the spot. Openspot writes it when you share or publish
the spot, and refuses a shared spot whose files don't match its last release. A spot reads nothing from it.

## The account

The account is the key that signs what you publish. Its 12 words give the key as NIP-06 says, so they open the same
account in another Nostr client.

- `openspot account show` tells any spot the public facts: whether an account is signed in, its `npub`, the `handle`
  it was made with, the day it was made (`since`), whether its words are backed up, and whether it syncs.
- No call prints or takes the 12 words. `account new`, `account sign-out` and `account sync` answer only a spot of
  `spots/openspot.spot` that names `account` in its uses. The Account page of Settings shows, checks and takes the words
  inside the app, and it asks for Touch ID or the Mac's password before each act on the key. An unlock counts for 5
  minutes, and only for the act it was asked for. A Mac with neither a password nor Touch ID cannot unlock the key.
- `store publish` signs with the key, so it answers only a spot of `spots/openspot.spot` that names `account` in its
  uses, and only while the app runs. Openspot removes `account` from the uses of any other spot, and
  `openspot check spots` reports it. The calls of such a spot stay out of the call log and the playground.
