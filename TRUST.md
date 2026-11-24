# Trust in Openspot

A spot runs with your rights. This page says what Openspot shows you about a spot before you add it, what it records
after each use, and how Careful mode and signed releases limit what a spot can do.

```toml
title = "Coffee"
uses = ["app"]
```

```sh
#!/bin/sh
openspot app quit
```

Coffee names `app` in its `uses`, so its quit of Openspot is a use it declared. Openspot asks you nothing in daily use.
It shows what a spot can do when you add or update it, and shows each use after it happens.

## Uses

`uses` in a spot's `spot.toml` names what the spot uses. Openspot doesn't load a spot with an unknown use.

| Use         | The calls that need it                                                                                                                                          |
| ----------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `app`       | `app quit`, each call of `theme` but `theme list`, `update check`, `update install`, and `setting set` of `menubar`, `open`, `float`, `key.<action>` or of the spot `openspot` |
| `spots`     | `spot add`, `spot remove`, `spot settings`, `spot edit`, `spot prompt`, `spot share`, `spot delete`, `spot new`, `spot run`, `spot log`, `setting list`, `setting set` of `enabled`, and `setting get`, `set` or `change` of another spot |
| `screen`    | `screen sources`, `screen shot`, `screen record`, `window frame`, `window move` and `color pick`                                                                |
| `clipboard` | `clipboard copy`, `clipboard paste` and `clipboard read`                                                                                                        |
| `calendar`  | each call of `calendar` and `reminders`                                                                                                                         |
| `power`     | `power lid-closed`                                                                                                                                              |
| `timer`     | each call of `timer`                                                                                                                                            |
| `attachment` | `attachment add`. A spot with it runs when the panel opens, stays off the grid, and puts a value in the panel's field.                                             |
| `read`      | `browser tab`, `browser tabs`, `finder selection`, `window selection`, `access list` and `access ask`. A read from `show` never asks macOS for access, and fails when Openspot doesn't have it yet.                                             |
| `network`   | No call. The spot reaches the network.                                                                                                                          |
| `files`     | No call. The spot writes outside its data folder.                                                                                                               |
| `account`   | `store publish`. Only a spot of `spots/openspot.spot` can have it; see [The account](#the-account).                                                             |

- A call that needs a use the manifest doesn't name still runs, and shows one toast for each spot, use and day.
  `openspot check spots` can't report it, because only a run shows it. `openspot spot stats` lists each such call.
- Openspot knows which spot makes each call of `openspot` by the link it gives each process of the spot on file
  descriptor 11, not from the variables of the process. Each process that the spot starts inherits it, so leave fd 11
  open, and start a command from Swift with `posix_spawn`, since Foundation's `Process` closes it. An app that the spot
  opens doesn't get it, and the link ends with the spot's process. A process of the spot that closed fd 11 is still
  known by the process group that Openspot started it in, but only the link lets it run another spot with
  `openspot run` or tell other spots with `openspot emit`. A call that runs in a process of its own, such as one that
  the running app hands back, runs with the rights of the spot's process and nothing more.
- Only your own processes can reach the API.
- No other spot and no Terminal reads a secret setting: `setting get` and `setting list` print `•••` for it, and
  `setting set` of it fails. Only its own spot reads it, with `setting get`, and only Openspot's own form changes it.
  Openspot keeps a secret in the Keychain, under the spot's id and the setting's key, never in the config, and removes
  it with the spot.

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

## Careful mode

Careful mode runs each process of a spot in a sandbox. It's a setting of the Settings spot, off by default.

- A spot gets no network unless `uses` names `network`, and writes only to its data folder and the temp folders unless
  it names `files`. With `screen`, it can also write to the Desktop, Movies and the screenshots folder.
- In Careful mode, a call that needs a use the manifest doesn't name fails.
- Without Careful mode, the data folder is no boundary.

## Signed releases

A spot folder can hold `releases.jsonl`, the signed releases of the spot. Openspot writes it when you share or publish
the spot, and refuses a shared spot whose files don't match its last release. A spot reads nothing from it.

## The account

The account is the key that signs what you publish. Its 12 words give the key as NIP-06 says, so they open the same
account in another Nostr client.

- `openspot account show` tells any spot the public facts: whether an account is signed in, its `npub`, the `handle`
  it was made with, the day it was made (`since`), whether its words are backed up, and whether it syncs.
- No call makes, changes or removes the account key, and none prints or takes the 12 words. Only the Account sheet of
  the app does, and it asks for Touch ID or the Mac's password before each act on the key. An unlock counts for 5
  minutes, and only for the act it was asked for. A Mac with neither a password nor Touch ID cannot unlock the key.
- `store publish` signs with the key, so it answers only a spot of `spots/openspot.spot` that names `account` in its
  uses, and only while the app runs. Openspot removes `account` from the uses of any other spot, and
  `openspot check spots` reports it. The calls of such a spot stay out of the call log and the playground.
