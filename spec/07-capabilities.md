# 07 Capabilities

`final` `optional` · Needs 01.

A script finds `openspot` first on its `PATH`. It gives what macOS has no command for, in plain text. A capability is
`openspot <noun> <verb>`, and it works the same from a script and from a terminal (K1). `openspot help` prints each call,
with its flags and what it prints.

| Noun | Gives |
|---|---|
| `check`, `catalog`, `render`, `sandbox` | Tools for authors: the faults of a plugin or a sheet, the sheet language, a picture of a sheet, a window to try one. |
| `color` | The colour that the person picks. |
| `clipboard` | A copy of a file as Finder does it, and a paste into the front app. |
| `translate` | A translation of stdin on this Mac. |
| `emoji`, `symbols` | Each emoji or symbol as a row, with its name in the language of the Mac. |
| `window` | The frame of the front window, and a move of it. |

When macOS already has a command, use it: `pbcopy`, `open`, `say`, `caffeinate`, `mdfind`, `screencapture`,
`shortcuts run`, `osascript`.

- A capability that cannot answer prints `status=<word>` (K4). One that cannot start what it needs exits with 1, and one
  line on stderr says the cause and the fix.
- A capability with state, such as `translate`, keeps it in a helper. A script never starts, finds or stops a helper (K3).
- Each usage text for a protected Mac feature is in the app, so a protected feature is a capability (P5).

A capability is added only when macOS has no command for it, when it needs a usage text in the app, or when it needs state
between calls.

## Decisions

| Decision | Rejected |
|---|---|
| State lives behind a capability, so a script stays a handler, with no fifo and no server. | A server in each plugin. |
| A capability exits when idle: one rule, the same from a terminal. | State that ends with its sheet. |
| The platform's own command, with no wrapper of the same name. | `openspot copy` beside `pbcopy`. |
