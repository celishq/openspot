# The openspot command

`draft` `optional` · Builds on [01](01-spot.md) and [06](06-actions.md) · Uses [10](10-other-spots.md#openspot-run)

Use this when your spot needs the Mac or Openspot, such as the clipboard, a window, a toast or a timer.
`openspot <noun> <verb>` is the one way a spot asks for anything, and it works the same in a terminal.

```text
$ openspot calc solve 2+2
item=4
title=4
```

[The openspot commands](../../app/Help/commands.md) lists each command, and `openspot help <noun>` prints the verbs of
one noun.

## Uses

`uses` in `spot.toml` names the features of the Mac that your spot uses:

```toml
title = "Windows"
icon = "macwindow"
uses = ["screen"]
```

- A noun names its commands, its events and its use, such as `openspot clipboard copy`, `clipboard.change` and
  `clipboard` in `uses`.
- [Uses](../../TRUST.md#uses) lists each use and the commands that need it. The person sees them when they add your
  spot.
- `openspot spot actions` lists the commands of a spot's uses, and `openspot types` types them for its code.

## How a command ends

- A command exits 0 when it's done, 1 when it failed, 2 when `openspot` doesn't take its words, 3 when Openspot didn't
  answer, and 4 when the person closed what it showed.
- A list prints blocks, or JSON with `--json`. In the [shell helper](01-spot.md#the-shell-helper),
  `openspot_value <key> <text>` prints each value of a key in what a command printed, and `openspot_rows <key>...`
  prints a line of tab-separated values for each block of stdin.
- `openspot_paste <text>` of the shell helper pastes the text into the front app, with `clipboard` in `uses`.
- A command that changes the Mac or Openspot, waits for the person, or opens a window fails in a read; see
  [the commands that fail in a read](../../app/Help/commands.md#the-commands-that-fail-in-a-read).
- `openspot toast <words>` shows the words for a moment, even when the panel is closed. `openspot select <item>`
  selects an item once the next frame shows.

## Write a message

A toast or a failure line tells the person what happened and what to do next.

- Instead of `Oops! Something went wrong.`, write `Openspot cannot find a screenshot.`
- Instead of `Error 1: osascript failed.`, write ``Copied, but Openspot cannot paste. Press `⌘V`, or allow Openspot in
  Accessibility.``

Say what still worked, and the step that fixes the rest, in one or two calm sentences. Put each key in backticks.

## openspot timer

`openspot timer add <time> <action> [<name>=<value>...]` adds a timer, which runs an [action](06-actions.md) of your
spot at a time, even when the panel is closed. It needs `timer` in `uses`.

```toml
title = "Stretch"
icon = "figure.walk"
uses = ["timer"]

[actions.remind]
inputs.words = { type = "text", required = true }
```

```sh
#!/bin/sh
. "$OPENSPOT_SH"
case "$1" in
  show) printf 'button=later\ntitle=Remind me in an hour\nscope=spot\n' ;;
  later) openspot timer add "$(date -u -v+1H +%Y-%m-%dT%H:%M:%SZ)" remind words="Time to stretch" ;;
  remind) openspot toast "$(value words)" ;;
esac
```

Remind me in an hour in the ⌘K menu adds a timer. An hour later, Openspot calls `remind` with
`input.words=Time to stretch`, and a toast shows the words.

- The time is ISO 8601 with its offset, or `someday`, which never comes due. The command prints the timer's id.
- Openspot checks the inputs against the action as [`openspot run`](10-other-spots.md#openspot-run) does, and exits 2
  on a wrong one.
- A time that has passed comes due at once, such as after the Mac slept.
- `openspot timer list` prints an item for each timer of the spot, with its action as `title`, its time as `at` and
  each input as `input.<name>=`. `openspot timer remove <id>` removes one.
- A timer lasts across a restart, and only its own spot sees it.
