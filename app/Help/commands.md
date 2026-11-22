# The openspot commands

`draft` · `openspot guide commands` prints this page. It lists the commands of the `openspot` command that a spot or a
terminal can run, and how each one ends. `openspot help` lists every verb, grouped by what it's for.

```sh
openspot help clipboard
openspot calc solve 2+2
```

The first call prints the verbs of one noun, then its guide when it has one, such as `screen` or `calendar`. The second
prints the answer to a sum as an item.

## How a call ends

- A call exits with code 0 when it's done, 1 when it failed, 2 when `openspot` doesn't take its words, and 3 when it
  needs the app and no app answered. Words that `openspot` doesn't take print the verbs of the noun they name, or the
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
  `openspot calc solve` prints `status=offline` or `status=unavailable` for a currency with no rates.
- Each call that lists or reports, such as `app status`, `power readings`, `account show`, `spot list`, `spot stats`,
  `store list`, `setting list` and `theme list`, prints blocks, the format of a frame. `--json` prints JSON.
- `openspot batch` runs one call for each line of stdin, and prints `---` after each. It stops at the first failure.

## The calls that fail in a show

A show changes nothing and opens nothing, so these calls fail in it:

- calls that wait for the user: `color pick` and `folder pick`;
- calls that capture the screen: `screen shot`, `screen record start` and `screen record stop`;
- calls that change the Mac or the user's data: `window move`, `clipboard copy`, `clipboard paste`,
  `power lid-closed`, `calendar add`, `reminders add`, `reminders done`, `spot add`, `spot remove` and `spot delete`;
- calls that change Openspot or its places: `app quit`, each call of `theme` but `theme list` and `theme open`,
  `update install`, and `setting set` of a key that Openspot keeps for the user;
- calls that move the flow of sheets: `route push`, `route back` and `route close`;
- calls that open a window or the panel: `spot open`, `spot choose`, `spot settings`, `spot edit`, `spot prompt`,
  `spot share`, `spot review`, `grid edit`, `setting change`, `theme open`, `update check`, `calendar show` and
  `reminders show`.

`calendar add --dry-run` and `reminders add --dry-run` change nothing, so they work in a show. `toast` and `select`
work in a show too.

## Commands

The commands that try a spot are in [Try your spot](../../GUIDE.md#try-your-spot). The others:

| Command                                            | Does                                                                                            |
| -------------------------------------------------- | ----------------------------------------------------------------------------------------------- |
| `openspot guide [topic \| --topics]`               | Prints the guide, then the protocol. A topic prints one section or a page such as this one, and `--topics` lists them. |
| `openspot version`                                 | Prints the version of Openspot, as `openspot --version` does.                                   |
| `openspot toast <words>...`                        | Shows a short message, even when the panel is closed.                                           |
| `openspot select <item>`                           | Selects an item of the spot's sheet once the spot's next frame shows.                           |
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
| `openspot spot add <git url, folder or .spot>`     | Adds a spot, and records it in `spots.lock`. An update that needs a new use also needs `--yes`. |
| `openspot spot remove <id>`                        | Moves a spot that `spot add` added to the Trash.                                                |
| `openspot spot stats`                              | Prints what each spot cost and used. `openspot guide stats` explains it.                        |
| `openspot spot actions [id]`                       | Prints each action of a spot and each command of its uses, with their inputs and outputs as JSON Schema. |
| `openspot schema`                                  | Prints the JSON Schema of `spot.toml`, which an editor checks the file with.                    |
| `openspot timer add <time> <action> [<name>=<value>...]` | Calls an action of the spot at the time, with its inputs, checked when you add the timer.   |
| `openspot run <binding>.<action> [<name>=<value>...] [--out <name>] [--stdin <name>]` | Runs an action of a spot that your spot binds in its `[bindings]`, with its inputs checked, and waits for its values. It prints the `out.<name>` lines, or one value with `--out`, and `--stdin` reads that input from stdin. An action that answers with a view shows it over the sheet until a press in it gives values. It exits 1 when the action fails, 2 when it does not take the words, 3 when the action gives no values, and 4 when the person closes the view. It runs only in a run of a spot. |
| `openspot emit <event> [<name>=<value>...]` | Sends one of your spot's `[events]`, with its values checked. Each spot that binds yours and lists `<binding>.<event>` in its `[on]` gets a call of that handler. It runs only in a run of a spot. |
| `openspot grid edit`                               | Opens the panel in Edit Spots, to arrange the grid.                                             |
| `openspot store list [--json]`                     | Prints each spot of the store and its step: `get`, `publish`, or `added` once you have it.      |
| `openspot store get <id>`                          | Gets a spot of the store: turns it on, or adds its package to your spots folder.                |
| `openspot store add <folder>`                      | Adds a folder that holds spot folders as a store, so the Store lists its spots. The folder's name is the store's name. |
| `openspot store remove <folder>`                   | Removes a store that `store add` added. The spots you got from it stay.                         |
| `openspot store folders [--json]`                  | Prints the built-in store Openspot, which holds the examples, then each store that `store add` added, with its name and whether its folder is found. |
| `openspot store publish <id>`                      | Publishes a spot of your spots folder to the store. It needs a `readme.md` beside its script. Only the Store spot can run it, so you publish from the Store spot. |
| `openspot playground open [file]`                  | Opens the Playground on a spot that you type or on a file.                                      |
| `openspot check sheet`                             | Reports the faults of a sheet on stdin.                                                         |
| `openspot render sheet [--view <file>] <file.png>` | Draws the sheet on stdin to a picture, with its view from a Swift file.                         |
| `openspot render card <size> <file.png>`           | Draws the card of the sheet on stdin at a size, such as `wide`, to a picture.                   |
| `openspot render spot <id> <file.png>`             | Draws the sheet of an installed spot, or with `--card <size>` its card, to a picture. It draws the dark appearance, or the light one with `--light`. |
| `openspot render panel <file.png>`                 | Draws the panel with each installed spot on its grid.                                           |
| `openspot render store <file.png>`                 | Draws the window of the Store with each spot as its card.                                       |
| `openspot prompt new [words]...`                   | Prints a prompt that asks a coding agent to build a spot that does what the words say.          |
| `openspot prompt change <id> [words]...`           | Prints a prompt that asks a coding agent to change a spot as the words say, with what the stats counted of it over 14 days. With no words, its goal follows those counts. |
| `openspot prompt theme <name> [words]...`          | Prints a prompt that asks a coding agent to change a theme as the words say.                    |
| `openspot emoji list [--tone name]`                | Prints each emoji as an item, with its name in the language of the Mac.                         |
| `openspot symbols list`                            | Prints each symbol of the Character Viewer as an item.                                          |
| `openspot translate text [--from code] [--to code]` | Translates the text on stdin. `openspot translate languages` prints the languages it knows.     |
| `openspot theme <verb>`                            | Lists the themes, and uses, makes and changes one: `list`, `use`, `new`, `duplicate`, `rename`, `delete`, `open` and `reload`. |
| `openspot account show [--json]`                   | Prints the public facts of the account that signs what you publish.                             |
