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
| `openspot toast [words...]`                         | Shows a short message, even when the panel is closed. With no words, it reads [a toast](#a-toast) on stdin. It works in `show`. |
| `openspot toast remove <id>`                        | Takes your toast with the id away.                                       |
| `openspot select <item>`                            | Selects a row of your sheet once your next frame shows.                  |
| `openspot attachment add <kind>=<value>... [title=<words>] [app=<app>] [icon=<icon>]` | Puts a value in the panel's field: `file=` once for each file, `url=` or `text=`. `icon=` takes what [`icon`](spot-toml.md#keys) in spot.toml takes. It works in `show` and `attachment.pick`, and needs `attachment` in `uses`. |
| `openspot route push <route> [--title <words>] [--replace]` | Shows a page of your spot over the sheet.                        |
| `openspot route back [--root]`                      | Goes back one page, or to the first.                                     |
| `openspot route close`                              | Takes each sheet of your spot off.                                       |
| `openspot setting get <key>`                        | Prints a setting, such as a `secret`, which never comes on stdin.        |
| `openspot setting set <key> [value]`                | Keeps a setting, or removes it with no value.                            |
| `openspot folder pick`                              | Prints the folder people pick, or nothing after Cancel.                  |
| `openspot timer add <time> <action> [<name>=<value>...]` | Runs an action of your spot at an ISO 8601 time, or `someday`, and prints the timer's id. It needs `timer` in `uses`. |
| `openspot timer list`                               | Prints an item for each timer of your spot.                              |
| `openspot timer remove <id>`                        | Removes a timer.                                                         |
| `openspot run <binding>.<action> [<name>=<value>...] [--out <name>] [--stdin <name>]` | Runs an action of a spot you bind, and prints its values. |
| `openspot emit <event> [<name>=<value>...]`         | Sends one of your spot's events to each spot that listens.               |
| `openspot cache get <name>`                         | Prints the value your spot keeps as `<name>`, and runs its filler when it is missing or old. |
| `openspot cache age <name>`                         | Prints the seconds since your spot kept `<name>`, or nothing.            |
| `openspot cache set <name>`                         | Keeps stdin as `<name>`, and asks your spot again for the panel's search. |
| `openspot spot open <id>`                           | Opens the panel on a spot.                                               |
| `openspot front app`, `openspot browser tab <app>`, `openspot browser tabs <app>` or `openspot selection read <app>` | Prints what people work on, or nothing. It needs `read` in `uses`, and fails in `show` when Openspot may not read it yet. |
| `openspot clipboard read [--newer <age>]` | Prints the text on the clipboard. With `--newer`, it prints it only when Openspot first saw that copy within the age: seconds, or a number with `s`, `m`, `h` or `d`, such as `2m`. |
| `openspot date read <words>...`                     | Prints the date the words name, such as `25 dec`, as `item` and `time`, or nothing when they are more than a date. |

In each command, an app is its bundle ID, such as `com.apple.Safari`. Each list a command prints is blocks, as your script prints them, or JSON with `--json` where the command takes it.

## A toast

Up to three toasts wait in line. The newest shows, with a short bar under it for each toast in line, its own bright, and the next steps in when it leaves. A toast's time starts when it shows. A click on a toast closes it. A toast with no words reads blocks
on stdin, and its first block holds the toast's own keys:

```ini
toast=upload
title=Uploading 3 files
keep=true
action=open-uploads
```

| Key      | Is                                                                                    |
| -------- | ------------------------------------------------------------------------------------- |
| `toast`  | Its id. A later toast of your spot with the same id changes it in place.              |
| `title`  | The words it shows.                                                                   |
| `keep`   | `true` keeps it until a click or `openspot toast remove <id>`. Else it leaves after 5 seconds. |
| `action` | The action of your spot that a click runs. With none, a click opens your spot.        |
| `class`  | The classes of its layout, as `class` of a frame's first block.                       |

Each block after it is drawn with Openspot's own [blocks](blocks.md), such as a ring and a line of words. A block of a
view of your spot is a fault. The whole toast is one click, so a button in it does nothing. A `toast:` class shows a part
only in a toast, as `card:` does on a card.

```ini
toast=backup
class=flex-row items-center gap-2

number=done
value=72
max=100
unit=%
type=ring

text=words
title=Backup
detail=72% of 40 GB
```

## Write a message

A toast or a failure line tells people what happened and what to do next. Say what still worked, and the step that
fixes the rest, in one or two calm sentences. Put each key in backticks.

- Instead of `Oops! Something went wrong.`, write `Openspot cannot find a screenshot.`
- Instead of `Error 1: osascript failed.`, write ``Copied, but Openspot cannot paste. Press `⌘V`, or allow Openspot in
  Accessibility.``
