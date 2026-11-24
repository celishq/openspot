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

- calls that wait for the person: `color pick` and `folder pick`;
- calls that capture the screen: `screen shot`, `screen record start` and `screen record stop`;
- calls that change the Mac or the person's data: `window move`, `clipboard copy`, `clipboard paste`,
  `power lid-closed`, `calendar add`, `reminders add`, `reminders done`, `spot add`, `spot remove` and `spot delete`;
- calls that change Openspot or its places: `app quit`, each call of `theme` but `theme list` and `theme open`,
  `update install`, and `setting set` of a key that Openspot keeps for the person;
- calls that move the flow of sheets: `route push`, `route back` and `route close`;
- calls that open a window or the panel: `spot open`, `spot choose`, `spot settings`, `spot edit`, `spot prompt`,
  `spot share`, `spot review`, `grid edit`, `setting change`, `theme open`, `update check`, `calendar show` and
  `reminders show`.

`calendar add --dry-run` and `reminders add --dry-run` change nothing, so they work in a read. `toast` and `select`
work in a read too. `run` works in a read, but the action it runs can't show a view there.

## Commands

[Try it from the terminal](../../docs/first-spot.md#try-it-from-the-terminal) shows how the commands that try a spot work together.

| Command                                            | Does                                                                                            |
| -------------------------------------------------- | ----------------------------------------------------------------------------------------------- |
| `openspot guide [topic \| --topics]` | Prints the docs, from the map to the reference, then Use Openspot, or with a topic one page, such as this one. |
| `openspot version`                                 | Prints the version of Openspot, as `openspot --version` does.                                   |
| `openspot toast <words>...`                        | Shows a short message, even when the panel is closed.                                           |
| `openspot select <item>`                           | Selects an item of the spot's sheet once the spot's next frame shows.                           |
| `openspot attachment add <kind>=<value>... [title=<words>] [app=<bundle id>]` | Puts a value in the panel's field as the spot's chip: `file=` once for each file, `url=` or `text=`. |
| `openspot attachment empty <words>...`             | Shows the words in the panel's field when the spot's chip has nothing to hand over.             |
| `openspot route push <route> [--title <words>] [--replace]` | Shows a route of the spot over the sheet that shows.                                   |
| `openspot route back [--root]`                     | Goes back one sheet of the spot, or to its first sheet.                                         |
| `openspot route close`                             | Takes each sheet of the spot off.                                                               |
| `openspot spot open <id> [--select]`               | Opens the panel on a spot, as a new flow. `--select` only selects its card.                     |
| `openspot spot push <id> [page]`                   | Pushes a spot, or a page of it, over the flow that shows, or opens the panel on it when no sheet shows. |
| `openspot spot pop <id> [--all]`                   | Goes back one sheet of a spot that shows, or to its first sheet.                                |
| `openspot spot choose <id>`                        | Asks for files, and drops the chosen ones on a spot that takes them, as a press of its card does. |
| `openspot spot settings <id>`                      | Opens the Settings of a spot, as Settings in its ⌘K menu does.                                  |
| `openspot spot edit <id>`                          | Opens the Edit sheet of a spot, as Edit in its ⌘K menu does, or a file that doesn't load in the text editor. |
| `openspot spot prompt <id>`                        | Copies a prompt that asks a coding agent to change a spot.                                      |
| `openspot spot share <id>`                         | Shares a spot, as Share in its ⌘K menu does.                                                    |
| `openspot spot delete <id>`                        | Moves a spot to the Trash, and `⌘Z` in the panel puts it back.                                  |
| `openspot spot add <git url, folder or .spot>` | Adds a spot and records it in `spots.lock`, and an update that needs a new use also needs `--yes`. |
| `openspot spot remove <id>`                        | Moves a spot that `spot add` added to the Trash.                                                |
| `openspot spot stats`                              | Prints what each spot cost and used. `openspot guide stats` explains it.                        |
| `openspot spot actions [id]`                       | Prints each action of a spot and each command of its uses, with their inputs and outputs as JSON Schema. |
| `openspot schema`                                  | Prints the JSON Schema of `spot.toml`, which an editor checks the file with.                    |
| `openspot timer add <time> <action> [<name>=<value>...]` | Calls an action of the spot at the time; see [Run once, at a time](../../docs/react/on-a-schedule.md#run-once-at-a-time). |
| `openspot spot run <spot> <handler> [<name>=<value>...]` | Calls one handler of a spot as a call would, with its inputs checked and its bindings live, and prints its frame and values. |
| `openspot run <binding>.<action> [<name>=<value>...] [--out <name>] [--stdin <name>]` | Runs an action of a spot that your spot binds, and waits for its values; see [Use another spot](../../docs/connect/other-spots.md). |
| `openspot emit <event> [<name>=<value>...]` | Sends one of your spot's `[events]` to each spot that binds it; see [Tell other spots what happened](../../docs/connect/other-spots.md#tell-other-spots-what-happened). |
| `openspot types [id]` | Writes the types of a `.js` spot to `openspot.d.ts`, or of a `.swift` spot to `Openspot.swift`, beside its script, for the spot of the current folder when there is no id, and prints the file. |
| `openspot grid edit`                               | Opens the panel in Edit Spots, to arrange the grid.                                             |
| `openspot store list [--json]`                     | Prints each spot of the store and its step: `get`, `publish`, or `added` once you have it.      |
| `openspot store get <id>`                          | Gets a spot of the store: turns it on, or adds its package to your spots folder.                |
| `openspot store add <folder>` | Adds a folder of spot folders as a store, named like the folder, so that the Store lists its spots. |
| `openspot store remove <folder>` | Removes a store that `store add` added, and keeps the spots you got from it. |
| `openspot store folders [--json]`                  | Prints the built-in store Openspot, which holds the examples, then each store that `store add` added, with its name and whether its folder is found. |
| `openspot store publish <id>` | Publishes a spot of your spots folder, with a `readme.md` beside its script, from the Store spot alone. |
| `openspot playground open [file]`                  | Opens the Playground on a spot that you type or on a file.                                      |
| `openspot spot new <name> --from <kind>`           | Writes a spot folder that works, from the kind `button`, `list`, `number` or `form`.             |
| `openspot spot log <id>`                           | Prints the last calls of a spot, with their stdin, stdout, stderr and exit code.                |
| `openspot check spots [--json] <folder>`           | Loads and runs each spot of the folder once, and prints a `fault` block for each error.         |
| `openspot check sheet`                             | Reports the faults of a sheet on stdin.                                                         |
| `openspot render sheet [--view <file>] <file.png>` | Draws the sheet on stdin to a picture, with its view from a Swift file.                         |
| `openspot render card <size> <file.png>`           | Draws the card of the sheet on stdin at a size, such as `wide`, to a picture.                   |
| `openspot render spot <id> <file.png>` | Draws the sheet of an installed spot, or with `--card <size>` its card, in the dark appearance, or the light one with `--light`. |
| `openspot render panel <file.png>`                 | Draws the panel with each installed spot on its grid.                                           |
| `openspot render store <file.png>`                 | Draws the window of the Store with each spot as its card.                                       |
| `openspot prompt new [words]...`                   | Prints a prompt that asks a coding agent to build a spot that does what the words say.          |
| `openspot prompt change <id> [words]...` | Prints a prompt that asks a coding agent to change a spot as the words say, with what the stats counted of it over 14 days, or with no words a goal that follows those counts. |
| `openspot prompt theme <name> [words]...`          | Prints a prompt that asks a coding agent to change a theme as the words say.                    |
| `openspot date read <words>...`                    | Prints the date the words name, such as `tomorrow 3pm`, as `item=yyyy-MM-dd HH:mm` in the zone of the Mac, or with no time `item=yyyy-MM-dd`, and `time=true` or `false`. It prints nothing when the words are more than a date. |
| `openspot read tab` | Prints the `url=`, `title=` and `app=` of the front tab when a browser is in front, or nothing. |
| `openspot read finder` | Prints a `file=` for each file selected in Finder, and `app=`. |
| `openspot read selection` | Prints the `text=` selected in the front app, and its `app=`. |
| `openspot read clipboard` | Prints the `text=` on the clipboard, or `url=` when it holds one link, and `age=`, the seconds since Openspot first saw that copy. |
| `openspot read --access` | Prints `reader=`, `app=` and `access=` for each reader: `allowed`, `denied`, `unasked`, or `unknown` while its app is closed. |
| `openspot emoji list [--tone name]`                | Prints each emoji as an item, with its name in the language of the Mac.                         |
| `openspot symbols list`                            | Prints each symbol of the Character Viewer as an item.                                          |
| `openspot translate text [--from code] [--to code]` | Translates the text on stdin. `openspot translate languages` prints the languages it knows.     |
| `openspot theme <verb>`                            | Lists the themes, and uses, makes and changes one: `list`, `use`, `new`, `duplicate`, `rename`, `delete`, `open` and `reload`. |
| `openspot account show [--json]`                   | Prints the public facts of the account that signs what you publish.                             |
