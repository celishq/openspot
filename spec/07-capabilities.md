# 07 Capabilities

`final` · Needs 01.

A script finds `openspot` on its path. It gives what macOS has no command for, in plain text.

| Call | Does |
|---|---|
| `openspot check [folder]` | Reports the faults of a plugins folder. |
| `openspot check --sheet` | Reports the faults of a sheet on stdin. |
| `openspot catalog` | Prints the whole sheet language, with examples. |
| `openspot render <file.png>` | Draws the sheet on stdin to a picture. |
| `openspot sandbox [file]` | Opens a window to try a sheet from text, a file or a script. |
| `openspot color pick` | Prints the colour the person picks. Prints nothing on a cancel. |
| `openspot clipboard copy [file]` | Copies the file as Finder does, with the picture of an image. With no file, it copies the text on stdin. |
| `openspot clipboard paste` | Pastes the clipboard into the front app. Without Accessibility it prints the `open=` fix and exits with 1. |
| `openspot translate [--from code] [--to code]` | Translates the text on stdin on this Mac. Prints `text` and `from`, or `status=missing`, `unsupported`, `unknown` or `failed`. |
| `openspot translate languages` | Prints each language, with its name. |
| `openspot emoji [--tone name]` | Prints each emoji as a row, with its name in the language of the Mac. A tone is `none`, `light`, `medium-light`, `medium`, `medium-dark` or `dark`. |
| `openspot symbols` | Prints each symbol of the Character Viewer as a row, with its Unicode name and the title of its section in the language of the Mac. |
| `openspot window frame` | Prints the front window, then the usable area of its screen, as `x y width height x y width height` in points from the top left of the main screen. Needs Accessibility. |
| `openspot window move frame...` | Moves the front window to a frame, `x y width height`. A percent, a fraction or a plain number from 0 to 1 is a part of the usable area of the window's screen, so `0 0 1 1` and `0% 0% 100% 100%` fill it. Any other number is points. With more frames, such as `"0 0 1/4 1" "0 0 1/3 1"`, it moves to the frame after the one the window holds, within 20 points, or to the first. A window that keeps its own size holds the edges of the screen that the frame touches. Needs Accessibility. |

When macOS already has a command, use it: `pbcopy`, `open`, `say`, `caffeinate`, `mdfind`, `screencapture`,
`shortcuts run`, `osascript`.

A capability works the same from a script and from a terminal. It can stay loaded between calls: `openspot translate`
keeps each pair of languages in memory, and they leave memory 30 seconds after the last call. Your script does nothing for
this. It never starts, finds or stops anything, and it stays a handler that runs once for each call, as `translate.sh` does.
When a call cannot start what it needs, it exits with code 1 and one line on stderr that says the cause and the fix.

To use `openspot` in a terminal, turn on Use openspot in Terminal in Settings. It links `/usr/local/bin/openspot` to the
command inside the app, and macOS asks for your password when that folder needs it.

## Rules

| ID | Rule |
|---|---|
| K1 | A capability is `openspot <noun> <verb>`. It works the same from a script and from a terminal. |
| K2 | A capability with state keeps it in a helper. The helper starts at the first call, and exits after 30 seconds with no call. |
| K3 | A script never starts, finds or stops a helper, and the app does not track it. |
| K4 | A capability prints `status=<word>` when it cannot answer. |
| P5 | Each usage text for a protected Mac feature is in the app, so a protected feature is a capability. |

A capability is added only when macOS has no command for it, when it needs a usage text in the app, or when it needs state
between calls.

## Why not

| Decision | Why | Rejected |
|---|---|---|
| State behind a capability | A script stays a handler, with no fifo and no server. | A server in each plugin. |
| A capability exits when idle | One rule, the same from a terminal, and the app does not track sheets for it. | State that ends with its sheet. |
| The platform's own command, with no wrapper of the same name | A script stays in the shell that authors and models know, and nothing is left to maintain. | `openspot copy` beside `pbcopy`. |
