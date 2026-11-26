# The openspot commands

`draft` · `openspot guide commands` prints this page. It lists the commands of the `openspot` command that a spot or a
terminal can run, and how each one ends. `openspot help` lists every verb, grouped by what it's for.

```sh
openspot help clipboard
openspot emoji list
```

The first call prints the verbs of one noun, then its guide when it has one, such as `screen` or `calendar`. The second
prints each emoji as an item.

## How a call ends

- A call exits with code 0 when it's done, 1 when it failed, 2 when `openspot` doesn't take its words, 3 when it
  needs the app and no app answered, and 4 when the person closed what it showed, as `run` does. Words that `openspot` doesn't take print the verbs of the noun they name, or the
  command they're closest to.
- `openspot help <noun>`, or `--help` after a noun or a verb, prints only its verbs. `openspot help --json` prints each
  verb with its form, its effect and whether it needs the app.
- A call that reads files or asks the Mac gives the same answer whether Openspot is running or not. A call that needs
  the running app starts it, and waits up to 10 seconds. Ctrl-C stops a call, and the stopped work changes nothing.
- `openspot --config <folder> <call>` reaches the Openspot that runs on that config folder. Within a spot, `openspot`
  reaches the app that ran the spot.
- A capability that can't answer prints `status=<word>`. `openspot translate text` prints `status=unknown` when it
  cannot tell the language of the text, `status=missing` when macOS has not downloaded a language,
  `status=unsupported` when it knows no way between the two, and `status=failed` for any other fault.
- Each call that lists or reports, such as `app status`, `power readings`, `account show`, `spot list`, `spot stats`,
  `store list`, `setting list` and `theme list`, prints blocks, the format of a frame. `--json` prints JSON.
- `openspot batch` runs one call for each line of stdin, and prints `---` after each. It stops at the first failure.

## The commands that fail in a read

A read, such as `show`, `search`, `every` or an event's handler, changes nothing and opens nothing, so these commands
fail in it:

- calls that wait for the person: `color pick`, `folder pick` and `access ask`;
- calls that capture the screen: `screen shot`, `screen record start` and `screen record stop`;
- calls that change the Mac or the person's data: `window move`, `clipboard copy`, `clipboard paste`,
  `power lid-closed`, `calendar add`, `reminders add`, `reminders done`, `spot add`, `spot remove` and `spot delete`;
- calls that change Openspot or its places: `app quit`, `app restart`, each call of `theme` but `theme list` and
  `theme open`, `update install`, `spot allow`, and `setting set` of a key that Openspot keeps for the person;
- calls that move the flow of sheets: `route push`, `route back` and `route close`;
- calls that open a window or the panel: `app settings`, `spot open`, `spot choose`, `spot edit`, `spot prompt`,
  `spot share`, `spot review`, `grid edit`, `setting change`, `theme open`, `update check`, `calendar show` and
  `reminders show`.

`calendar add --dry-run` and `reminders add --dry-run` change nothing, so they work in a read. `toast` and `select`
work in a read too. `run` works in a read, but the action it runs can't show a view there.

## Commands

[Build and check a spot](../../docs/build-and-check-a-spot.md) shows how the commands that try a spot work together. In each command, an app is its bundle ID, such as `com.apple.Safari`.

| Command                                            | Does                                                                                            |
| -------------------------------------------------- | ----------------------------------------------------------------------------------------------- |
| `openspot guide [topic \| --topics]` | Prints the docs, from the map to the reference, then Use Openspot, or with a topic one page, such as this one. |
| `openspot version`                                 | Prints the version of Openspot, as `openspot --version` does.                                   |
| `openspot toast [--id <id>] [--action <name>] [--class <classes>] [--view <blocks>] <words>...` | Shows a short message, even when the panel is closed. [A toast](../../docs/reference/commands.md#a-toast) has the options. |
| `openspot toast --remove <id>`                     | Takes the spot's toast with the id away.                                                        |
| `openspot select <item>`                           | Selects an item of the spot's sheet once the spot's next frame shows.                           |
| `openspot attachment add <kind>=<value>... [title=<words>] [app=<app>] [icon=<icon>]` | Puts a value in the panel's field as the spot's chip: `file=` once for each file, `url=` or `text=`. `icon=` takes what `icon` in spot.toml takes. |
| `openspot attachment add clipboard [--within <age>]` | Puts what the clipboard holds in the panel's field: its files, a link, a text or an image, and nothing for a password. The chip keeps the first million characters of a longer text, and the spot that takes it gets the whole text, read when people hand it on. An image is saved to a file only then. With `--within`, it adds only a copy that Openspot first saw within the age, as `clipboard read` takes it. It needs `attachment` and `clipboard` in `uses`. |
| `openspot route push <route> [--title <words>] [--replace]` | Shows a route of the spot over the sheet that shows.                                   |
| `openspot route back [--root]`                     | Goes back one sheet of the spot, or to its first sheet.                                         |
| `openspot route close`                             | Takes each sheet of the spot off.                                                               |
| `openspot spot open <id> [--select]`               | Opens the panel on a spot, as a new flow, or its window. `--select` only selects its card.      |
| `openspot spot push <id> [page]`                   | Pushes a spot, or a page of it, over the flow that shows, or opens the panel on it when no sheet shows. |
| `openspot spot pop <id> [--all]`                   | Goes back one sheet of a spot that shows, or to its first sheet.                                |
| `openspot spot choose <id>`                        | Asks for files, and drops the chosen ones on a spot that takes them, as a press of its card does. |
| `openspot spot edit <id>`                          | Opens the Edit sheet of a spot, as Edit in its ⌘K menu does, or a file that doesn't load in the text editor. |
| `openspot spot prompt <id>`                        | Copies a prompt that asks a coding agent to change a spot. A spot that comes with Openspot refuses it, and `spot edit`, `spot delete`, `spot remove` and `prompt change` too. |
| `openspot spot share <id>`                         | Shares a spot, as Share in its ⌘K menu does.                                                    |
| `openspot spot delete <id>`                        | Moves a spot's folder to the Trash, as Remove in its ⌘K menu does. Its data stays.              |
| `openspot spot add <git url, folder or .spot>` | Adds a spot and records it in `spots.lock`, and an update that needs a new use also needs `--yes`. |
| `openspot spot remove <id>`                        | Moves a spot that `spot add` or `store get` added to the Trash. Its data stays.                 |
| `openspot spot allow <id> <use>` | Lets a spot that `spot add` added make the calls of a use that its `spot.toml` doesn't name, and records the use in `spots.lock`, as an update with `--yes` does. Only the person can run it. |
| `openspot spot list [--core] [--json]` | Prints an `item=<id>` record for each spot: its `state=` (`ready`, `access` or `review`), its `uses=`, the macOS accesses it `needs=` that are denied or not asked yet, the uses it was `refused=`, the time of its last call of each use as `last.<use>=`, and the accesses that the calls of each use need as `access.<use>=`, or may need as `maybe.<use>=`. `--core` prints each spot that comes with Openspot, with `own=` when a spot of your spots folder takes its place. |
| `openspot setting list [--spot <id>] [--json]` | Prints a record for each row of Settings, of the app and of each spot, or of one spot, `openspot` for the app: `item=`, `spot=`, `name=` (the spot's name), `key=` (what `setting set` takes), `title=`, `value=` (`set` for a secret), `kind=`, `section=`, `icon=` and `detail=`, and for a choice its `options=` and `default=`. |
| `openspot setting remove [--spot <id>] <key>` | Removes a value, a secret too. Only you can, in Settings or in Terminal; a spot cannot. |
| `openspot spot stats`                              | Prints what each spot cost and used. `openspot guide stats` explains it.                        |
| `openspot spot actions [id]`                       | Prints each action of a spot and each command of its uses, with their inputs and outputs as JSON Schema. |
| `openspot schema`                                  | Prints the JSON Schema of `spot.toml`, which an editor checks the file with.                    |
| `openspot timer add <time> <action> [<name>=<value>...]` | Calls an action of the spot at the time; see [Run once, at a time](../../docs/react/on-a-schedule.md#run-once-at-a-time). |
| `openspot spot run <spot> <handler> [<name>=<value>...]` | Calls one handler of a spot as a call would, with its inputs checked and its bindings live, and prints its frame and values. |
| `openspot run <binding>.<action> [<name>=<value>...] [--out <name>] [--stdin <name>]` | Runs an action of a spot that your spot binds, and waits for its values; see [Use another spot](../../docs/connect/other-spots.md). |
| `openspot emit <event> [<name>=<value>...]` | Sends one of your spot's `[events]` to each spot that binds it; see [Tell other spots what happened](../../docs/connect/other-spots.md#tell-other-spots-what-happened). |
| `openspot types [id]` | Writes the types of a `.js` spot to `openspot.d.ts`, or of a `.swift` spot to `Openspot.swift`, beside its script, for the spot of the current folder when there is no id, and prints the file. |
| `openspot grid edit`                               | Opens Arrange, where you pin your spots to the grid and take them off.                          |
| `openspot grid list [--json]`                      | Prints each of your spots, the ones off the grid first, with grid=true or grid=false.           |
| `openspot grid pin <id>`                           | Puts a spot of yours that is off the grid in the first free slot.                               |
| `openspot store list [--json]`                     | Prints each spot of the store and its step: `get`, or `added` once you have it. First it updates each spot that `store get` installed and you didn't edit, when its store has a newer version that asks for nothing new. `copy` marks a spot whose update waits for `--yes` (`update`) and one you edited (`edited`). |
| `openspot store get <id> [--yes] [--replace] [--keep-both]` | Installs a spot of a store: copies its folder into your spots folder, where search finds it, and leaves it off the grid. A spot that the review would warn of prints the review and installs only with `--yes`. When your spots have its id, `--replace` moves yours to the Trash first, and `--keep-both` installs it under a new id, such as `ports-2`, and its own `openspot spot run ports` runs the copy. |
| `openspot store update [<id>] [--yes]` | Updates a spot that `store get` installed to the newest version of its store, or each such spot with no id. An update that asks for a new use, binding or power prints only what it adds and needs `--yes`. A spot you edited takes no update. |
| `openspot store revert <id> [--yes]` | Moves a spot you edited to the Trash and installs the version of its store in its place. Its data stays. |
| `openspot store add <folder>` | Adds a folder of spot folders as a store, named like the folder, so that the Store lists its spots. |
| `openspot store remove <folder>` | Removes a store that `store add` added, and keeps the spots you got from it. |
| `openspot store open [<id>] [--search <text>]` | Opens the Store, at the page of a spot when given its id, or with the words of `--search` in its search. |
| `openspot store folders [--json]`                  | Prints the built-in store Openspot, which holds the examples, then each store that `store add` added, with its name and whether its folder is found. |
| `openspot playground open [file]`                  | Opens the Playground on a spot that you type or on a file.                                      |
| `openspot spot new <name> --from <kind>`           | Writes a spot folder that works, from the kind `button`, `list`, `number` or `form`.             |
| `openspot spot log <id>`                           | Prints the last calls of a spot, with their stdin, stdout, stderr and exit code.                |
| `openspot check spots [--json] <folder>`           | Loads and runs each spot of the folder once, and prints a `fault` block for each error.         |
| `openspot check sheet`                             | Reports the faults of a sheet on stdin.                                                         |
| `openspot render sheet [--view <file>] <file.png>` | Draws the sheet on stdin to a picture, with its view from a Swift file.                         |
| `openspot render card <size> <file.png>`           | Draws the card of the sheet on stdin at a size, such as `wide`, to a picture.                   |
| `openspot render spot <id> <file.png>` | Draws the sheet of an installed spot, or with `--card <size>` its card, in the dark appearance, or the light one with `--light`. |
| `openspot render panel [--arrange] [--search <text>] [--swap <id>] [--hold] [--light] <file.png>` | Draws the panel with each installed spot on its grid, dark or light; `--search` alone draws what a search finds; `--arrange` draws Arrange over a screen, with the words of `--search` and the spot of `--swap` lifted over the last card; `--hold` draws the grid while `⌘` is held. |
| `openspot render settings [--at <where>] [--light] <file.png>` | Draws the Settings window, opened at a place as `app settings --at` opens it, dark or light. |
| `openspot render store [--place <name>] [--spot <id>] [--try] [--review <id>] <file.png>` | Draws the window of the Store at My spots, or at the place that `--place` names, such as `Openspot`, with the page of `--spot` open, its Try with `--try`, or the review of an install of `--review` over it. |
| `openspot prompt new <words>...`                   | Prints a prompt that asks a coding agent to build a spot that does what the words say.          |
| `openspot prompt change <id> [words]...` | Prints a prompt that asks a coding agent to change a spot as the words say, with what the stats counted of it over 14 days, or with no words a goal that follows those counts, or else a review of the spot. |
| `openspot prompt theme <name> <words>...`          | Prints a prompt that asks a coding agent to change a theme as the words say.                    |
| `openspot date read <words>...`                    | Prints the date the words name, such as `tomorrow 3pm`, as `item=yyyy-MM-dd HH:mm` in the zone of the Mac, or with no time `item=yyyy-MM-dd`, and `time=true` or `false`. It prints nothing when the words are more than a date. |
| `openspot browser tab <app>` | Prints the `url=`, `title=` and `app=` of the front tab of the browser `<app>`, or nothing when it is not running. |
| `openspot browser tabs <app>` | Prints a record for each tab of each window of the browser `<app>`: `url=`, `title=`, `window=` (1 is the front window), `index=`, `active=` and `app=`. |
| `openspot selection read <app>` | Prints what is selected in the app `<app>`, and its `app=`: a `file=` for each file selected in Finder, or the `text=` selected in another app. It prints nothing when the app is not running or has no selection. |
| `openspot front app` | Prints the `app=` bundle ID, `name=` and `path=` of the app in front of Openspot, or nothing. |
| `openspot clipboard read [--within <age>]` | Prints the text on the clipboard. With `--within`, it prints it only when Openspot first saw that copy within the age: seconds, or a number with `s`, `m`, `h` or `d`, such as `2m`. |
| `openspot access list` | Prints an `item=<id>` record for each macOS access that a spot can need: `accessibility`, `automation`, `screen`, `calendars`, `reminders`, `camera`, `microphone`, `input` and `helper`. Each has its `title=`, its `access=`, the `spots=` that are on and need it for a call they make, and the spots that may need it for some forms of a call as `maybe=`. Then it prints `app=`, `path=` and `access=` for each app that Openspot reads. An access is `allowed`, `denied`, `unasked`, or `unknown`, as for an app that is closed. The record of the selected text has `app=accessibility`. |
| `openspot access grant <id>` | Opens Settings at a spot, and walks the person through each macOS access that it lacks, one at a time, beside System Settings. With an access, such as `screen`, it walks them through that one, at its page. |
| `openspot access grant [--end]` | Prints the guided grant that runs, as one `item=grant` block: its `spot=`, its `steps=`, the `step=` it waits on with the `place=` of its switch in System Settings, the steps it is `done=` with, and `restart=true` when the step needs Openspot to start again. It prints nothing when none runs. `--end` ends it. |
| `openspot access ask <app\|accessibility>` | Asks macOS for Openspot's access to the app, or to Accessibility, when the person has not chosen yet, and prints its record. |
| `openspot emoji list [--tone name]`                | Prints each emoji as an item, with its name in the language of the Mac.                         |
| `openspot symbols list`                            | Prints each symbol of the Character Viewer as an item.                                          |
| `openspot translate text [--from code] [--to code]` | Translates the text on stdin. `openspot translate languages` prints the languages it knows.     |
| `openspot theme <verb>`                            | Lists the themes, and uses, makes and changes one: `list`, `use`, `new`, `duplicate`, `rename`, `delete`, `open` and `reload`. |
| `openspot theme list [--json]` | Prints an `item=<name>` record for each theme, with `builtin=true` and `used=true` where they hold, and its colours: `dark.background=`, `dark.ink=`, `dark.accent=`, and the same of `light`. |
| `openspot app restart` | Ends the running app and starts it again. A guided grant at a step that needs the start, such as Screen Recording, opens again at that step. |
| `openspot app settings [--at <where>]` | Opens the Settings window, at a place when one is given: `access`, `access/<id>`, `spot/<id>`, `row/<spot>/<key>`, `keys`, `look`, `account`, `general`, `developer` or `search/<words>`. |
| `openspot account show [--json]`                   | Prints the public facts of the account that signs what you share.                               |
| `openspot account new [<handle>]` | Makes the account key, with the handle, and prints the account's record. Only Openspot's own spots can run it. |
| `openspot account sign-out` | Removes the account key from this Mac. Only Openspot's own spots can run it. |
| `openspot account sync on` | Keeps the account key in iCloud Keychain; `off` stops it. Only Openspot's own spots can run it. |
