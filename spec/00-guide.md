# Build an Openspot plugin

This guide is for people and for AI agents. It tells you all that you need. Each part after this one is a spec of its own,
and only 01 Core is needed for every plugin.

A plugin is one executable file in the plugins folder, in any language. Openspot reads the folder each time the panel
opens, so a new plugin needs no restart.

The rule: a script prints data, and Openspot draws it. A script can also open its own Mac window, which Openspot does not draw.

## The smallest plugin

File `hello.sh`. Make it executable with `chmod +x hello.sh`.

```sh
#!/bin/sh
say hello
```

This is a spot called Hello. A click runs it. Openspot never runs a script only to look at it, unless its header says so.

Keep several scripts together in a folder if you want. Each executable file is one spot, and a file that is not
executable can hold shared code.

The core spots come with the app, and the person turns them on or off in the Spots list. A file in the plugins folder with the
same name as a core spot takes its place, so to change a core spot, copy it there and edit the copy.

## A Swift plugin

A Swift file with `#!/usr/bin/env swift` on its first line is a script, with its header in `//` lines. `plugins/confetti.swift`
is an example that opens its own window on each screen.

```swift
#!/usr/bin/env swift
// name=Hello
// symbol=hand.wave
print("toast=Hello")
```

To run it, a Mac needs the Command Line Tools, from `xcode-select --install`. No Xcode app and no developer account are needed.
A person who gets it as a `.spot` file needs no tools. See 08 Sharing.

## Check your work

Run this before you stop. It loads each plugin and reads each one that has a `read`. It prints each fault, and it exits
with 1 when there is a fault. It does not run a script with no `read`.

```text
openspot check <plugins folder>
```

## Messages

A toast and a failure line are read in a second. Write each one as you would tell a friend what happened.

- Say what happened, and why when you know it. Never write "Something went wrong" when you know the cause.
- Say what still worked, such as `Copied.`
- Say how to fix it, with the exact step. When a link opens the fix, also print `open=<url>`.
- When the person cannot fix it, say what to try next.
- Name the problem, not the act of the person that caused it. Do not blame another app; say what Openspot could not do.
- Use plain words. No error codes, no internal names, no words such as "fetch" or "credentials".
- Keep a calm tone. No "Oops", no jokes and no exclamation marks. Write "please" only when the person can do nothing.
- Use one or two short sentences. Put each key in backticks, such as `` `⌘V` ``.

| Instead of | Write |
|---|---|
| `Oops! Something went wrong.` | `Openspot cannot find a screenshot.` |
| `Error 1: osascript failed.` | ``Copied, but Openspot cannot paste. Press `⌘V`, or allow Openspot in Accessibility.`` |
| `You did not install gh.` | `Pull requests need the gh tool. Install it, then open this again.` |

## Good habits

- Print only the data. Send each message for the person to stderr.
- Be fast in `read`, and do no work there.
- Keep files in `$OPENSPOT_DATA`, not in the plugin folder.
- Write a file to a temp name, then move it: `... > "$file.$$" && mv "$file.$$" "$file"`.
- Use short plain words in sentence case. Start an action's name with a verb.
- Do not use a `key` that another plugin has. The first plugin keeps it.
- A plugin runs with the full access of the person. If you are an agent, tell the person what yours runs.
