# The openspot command

Your spot asks Openspot for anything with `openspot <noun> <verb>`, and it works the same in a terminal. These are
the commands a spot uses most; [the openspot commands](../../app/Help/commands.md) lists every one, and
`openspot help <noun>` prints the verbs of one noun.

## How a command ends

| Exit code | Means                                                                       |
| --------- | --------------------------------------------------------------------------- |
| `0`       | It's done.                                                                  |
| `1`       | It failed. The message is on stderr.                                        |
| `2`       | `openspot` doesn't take its words, such as an unknown verb or a wrong input. |
| `3`       | It needs Openspot, and Openspot didn't answer.                              |
| `4`       | People closed what it showed, such as the view of `openspot run`.          |

A command that changes the Mac, waits for people or opens a window fails in a word that only shows, such as `show`;
see [the commands that fail in a read](../../app/Help/commands.md#the-commands-that-fail-in-a-read).

## Build and try a spot

| Command                                             | Does                                                                     |
| --------------------------------------------------- | ------------------------------------------------------------------------ |
| `openspot spot new <name> --from <kind>`            | Writes a spot that works, from `button`, `list`, `number` or `form`.     |
| `openspot spot run <id> [word] [<name>=<value>...]` | Runs one word of a spot as Openspot does, and prints what it printed.    |
| `openspot spot log <id>`                            | Prints the last runs of a spot, with their stdin, stdout, stderr and exit code. |
| `openspot check spots [--json] [folder]`            | Loads and runs each spot of a folder once, and prints a `fault` block for each mistake. |
| `openspot playground open [file]`                   | Shows a spot in a panel of its own, and runs it again each time you save. |
| `openspot spot actions [id]`                        | Prints each action of a spot and each command of its uses, with their inputs and outputs. |
| `openspot schema`                                   | Prints the JSON Schema of `spot.toml`.                                   |
| `openspot types [id]`                               | Writes `openspot.d.ts` beside a `.js` spot, or `Openspot.swift` beside a `.swift` spot. |

## While your spot runs

| Command                                             | Does                                                                     |
| --------------------------------------------------- | ------------------------------------------------------------------------ |
| `openspot toast [--id <id>] [--action <name>] [--class <classes>] [--view <blocks>] <words>...` | Shows a short message, even when the panel is closed. [A toast](#a-toast) has the rest. It works in `show`. |
| `openspot toast --remove <id>`                      | Takes your toast with the id away.                                       |
| `openspot select <item>`                            | Selects a row of your sheet once your next frame shows.                  |
| `openspot attachment add <kind>=<value>... [title=<words>] [app=<app>] [icon=<icon>]` | Puts a value in the panel's field: `file=` once for each file, `url=` or `text=`. `icon=` takes what [`icon`](spot-toml.md#keys) in spot.toml takes. On stdin, blocks after the value draw its [details](../connect/attachments.md#give-a-value). It works in `show` and `attachment.pick`, and needs `attachment` in `uses`. |
| `openspot attachment add clipboard [--within <age>]` | Puts what the clipboard holds in the panel's field: its files, a link, a text or an image, and nothing for a password or a one-time code. The chip keeps the first million characters of a longer text, and the spot that takes it gets the whole text, read when people hand it on. An image is saved to a file only then. With `--within`, it adds only a copy that Openspot first saw within the age, as `clipboard read` takes it. It needs `attachment` and `clipboard` in `uses`. |
| `openspot route push <route> [--title <words>] [--replace]` | Shows a page of your spot over the sheet.                        |
| `openspot route back [--root]`                      | Goes back one page, or to the first.                                     |
| `openspot route close`                              | Takes each sheet of your spot off.                                       |
| `openspot setting get <key>`                        | Prints a setting, such as a `secret`, which never comes on stdin.        |
| `openspot setting set <key> [value]`                | Keeps a setting, or removes it with no value.                            |
| `openspot folder pick`                              | Prints the folder people pick, or nothing after Cancel.                  |
| `openspot timer add <time> <action> [<name>=<value>...]` | Runs an action of your spot at an ISO 8601 time, or `someday`, and prints the timer's id. It needs `timer` in `uses`. |
| `openspot timer list`                               | Prints an item for each timer of your spot.                              |
| `openspot timer remove <id>`                        | Removes a timer.                                                         |
| `openspot timeline add [<key>=<value>...]`          | Adds an entry to your spot's timeline and prints its id: `text=`, `url=` or `file=` once for each file, with `title=`, `detail=`, `app=`, `icon=`, `key=` and `at=`. With none, it takes the same lines on stdin. It needs `timeline` in `uses`, and works in a show. |
| `openspot timeline get <id>` | Prints the whole value of the entry: its text, its link, or the path of each file on a line. |
| `openspot timeline list [--spot <id>] [--all] [--about <id>] [--within <age>] [--search <words>] [--order newest\|oldest] [--after <id>] [--limit <n>]` | Prints an item for each entry of your spot's timeline, newest first, or in the time order of `--order`. `--spot` and `--all` read other timelines and need `read`. `--about` keeps the entries of one spot and the sessions that open it. |
| `openspot timeline forget <id>`                     | Takes an entry out of the timeline.                                      |
| `openspot session open <id>`                        | Opens again the session of a timeline entry, as it was: its pages, the page it showed and its text. It asks the spot again and runs no action. |
| `openspot session back [<steps>]`, `forward [<steps>]` | Goes to the session before or after, as `⇧⌘[` and `⇧⌘]` do, and past the newest one to the grid. |
| `openspot panel open`, `close`                      | Opens the panel, as its key does, or closes it. |
| `openspot panel type <text> [--pace <ms>] [--clear]` | Types the text into the field one character at a time, `--pace` milliseconds apart (80 by default), after the text the field holds, or in place of it with `--clear`. |
| `openspot panel key <key>...`                       | Presses each key as the keyboard does, such as `return`, `escape`, `tab`, `up`, `down`, `cmd+k` or `shift+cmd+[`. |
| `openspot panel press <part>`                       | Presses a part of the open sheet by its id, such as a button. |
| `openspot panel state [--json]`                     | Prints what the panel shows: `open=`, `text=`, `sheet=`, `route=`, `selected=`, `menu=`, `chips=` and `moving=`. |
| `openspot panel wait <key>=<value>... [--within <age>]` | Waits until `panel state` shows each fact, for 10 s or the age of `--within`, and fails with the first fact it missed. Each other `panel` call returns once its change is applied, so a script needs no pause between them. |
| `openspot timeline restore <id>`                    | Brings back an entry forgotten in the last 10 minutes.                   |
| `openspot timeline keep <days>`, `pause <age>`, `resume` | Sets how many days every timeline keeps, adds nothing for the age, or ends the pause. Only you and Openspot's own spots can. |
| `openspot run <binding>.<action> [<name>=<value>...] [--out <name>] [--stdin <name>]` | Runs an action of a spot you bind, and prints its values. |
| `openspot emit <event> [<name>=<value>...]`         | Sends one of your spot's events to each spot that listens.               |
| `openspot cache get <name>`                         | Prints the value your spot keeps as `<name>`, and runs its filler when it is missing or old. |
| `openspot cache age <name>`                         | Prints the seconds since your spot kept `<name>`, or nothing.            |
| `openspot cache set <name>`                         | Keeps stdin as `<name>`, and asks your spot again for the panel's search. |
| `openspot spot open <id>`                           | Opens the panel on a spot, or its window.                                |
| `openspot front app`, `openspot browser tab <app>`, `openspot browser tabs <app>` or `openspot selection read <app>` | Prints what people work on, or nothing. It needs `read` in `uses`, and fails in `show` when Openspot may not read it yet. |
| `openspot clipboard read [--within <age>]` | Prints the text on the clipboard. With `--within`, it prints it only when Openspot first saw that copy within the age: seconds, or a number with `s`, `m`, `h` or `d`, such as `2m`. |
| `openspot clipboard read --blocks [--within <age>]` | Prints the copy in its kind, as `openspot timeline add` takes it: `text=`, `url=`, or `file=` once for each file, with an image saved to a file. It prints nothing for a password, a one-time code or a text over 25 MB. |
| `openspot date read <words>...`                     | Prints the date the words name, such as `25 dec`, as `item` and `time`, or nothing when they are more than a date. |

In each command, an app is its bundle ID, such as `com.apple.Safari`. Each list a command prints is blocks, as your script prints them, or JSON with `--json` where the command takes it.

## A toast

Up to twenty toasts wait in line. The newest shows, and the next steps in when it leaves. While more than one waits, the
menu bar icon counts them. A toast leaves 5 seconds after it shows. While the pointer is on it, it stays, and its time
starts again when the pointer leaves. A click on a toast closes it.

```text
openspot toast Saved.
openspot toast --id upload --action open-uploads Uploading 3 files.
openspot toast --id upload Uploaded 2 of 3 files.
openspot toast --remove upload
```

| Option             | Is                                                                                    |
| ------------------ | ------------------------------------------------------------------------------------- |
| `--id <id>`        | Its id. A later toast of your spot with the same id changes it in place.              |
| `--action <name>`  | The action of your spot that a click runs. With none, a click opens your spot.        |
| `--view <blocks>`  | Openspot's own [blocks](blocks.md) to draw in place of the words, such as a ring and a line of words. |
| `--class <classes>`| The classes of the view's layout, as `class` of a frame's first block.                |

Options come before the words. A block of a view of your spot is a fault. The whole toast is one click, so a button in
it does nothing. A `toast:` class shows a part only in a toast, as `card:` does on a card. A view may start with a block
of `toast=<id>` and the keys `title`, `action` and `class`, and an option wins over its key.

```text
view=$(printf 'number=done\nvalue=72\nmax=100\nunit=%%\ntype=ring\n\ntext=words\ntitle=Backup\ndetail=72%% of 40 GB\n')
openspot toast --id backup --class "flex-row items-center gap-2" --view "$view" Backup at 72%
```

In JavaScript, `env.toast("Uploading 3 files.", { id: "upload", action: "open-uploads" })` takes the same options.

## Write a message

A toast or a failure line tells people what happened and what to do next. Say what still worked, and the step that
fixes the rest, in one or two calm sentences. Put each key in backticks.

- Instead of `Oops! Something went wrong.`, write `Openspot cannot find a screenshot.`
- Instead of `Error 1: osascript failed.`, write ``Copied, but Openspot cannot paste. Press `⌘V`, or allow Openspot in
  Accessibility.``
