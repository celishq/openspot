# Openspot specs

These specs are the contract between a plugin and Openspot. The build joins them in order into one `GUIDE.md` inside the
app, which the New spot sheet opens and `openspot guide` prints for an AI. How the app itself works is in its code and in `app/RULES.md`.

| Spec                            | Status | Needs | What it holds                                                                                    |
| ------------------------------- | ------ | ----- | ------------------------------------------------------------------------------------------------ |
| [01 Core](01-core.md)           | draft  |       | The file, the header, the places, the calls, the frames, the blocks, rows, widgets and files out. |
| [03 Views](03-views.md)         | draft  | 01    | A plugin's own SwiftUI view in an area.                                                          |
| [05 Stay](05-stay.md)           | draft  | 01    | One process that stays and talks both ways over stdio, such as a local server.                   |

A number that a spec gave up is not used again.

## Goals

In order. An earlier goal wins when two goals conflict.

1. **A small plugin costs almost nothing.** One executable file. No build, no manifest, no account, no SDK.
2. **Openspot draws a plugin's data.** A script prints data, and Openspot draws it. A plugin can add its own SwiftUI
   view to its spot, and a script can open its own Mac window.
3. **Nothing runs by surprise.** Openspot runs a script only when a person acts or when its header says so.
4. **A plugin has real power.** It can use any Mac API, keep state in files, stream a long process and stay running.
5. **A coding agent writes a working plugin.** Given only `openspot guide` and one sentence, a coding agent writes a plugin
   that passes `openspot check --json` with `[]`, so that it shows on the grid, on its first try. `make eval-agent`
   measures it.

## How a spec is written

These rules come from the way Nostr writes its NIPs.

1. **One spec, one feature.** A host that skips a spec still works, and so does a script that ignores it.
2. **The head.** The number and the name, then `draft` or `final`, and `required` or `optional`, then the specs it needs.
3. **Only the contract.** What passes between a script and the host: the header, the arguments, stdin, stdout and the
   environment. Not how the host draws, its keys or its timings, unless a script must be written for a number.
4. **The example first.** One real example, then the rules.
5. **Each rule once,** in the prose. A rule keeps an ID, such as `C6`, only when code or a test names it, and an ID is
   never changed or used again.
6. **A short table of decisions** at the end: each choice that later work must not break, with the one it rejected.
7. **One way to do one thing,** and each word in one spec, as the registry shows.
8. **Final is final.** A draft becomes final when a real use proves it. A final spec never changes the meaning of a word:
   a new feature is a new word or a new spec.

## Registry

| Word                                                                                                     | Kind                 | Spec |
| -------------------------------------------------------------------------------------------------------- | -------------------- | ---- |
| `title`, `icon`, `detail`, `size`, `read`, `drop`, `offers`, `answers`, `press`                          | Header key           | 01   |
| `command`, `setting`                                                                                     | Header block         | 01   |
| `view`                                                                                                   | Header key           | 03   |
| `stay`                                                                                                   | Header key           | 05   |
| `sheet`, `panel`, a number                                                                               | Moment               | 01   |
| `search`, `rows`, `float`                                                                                | Place                | 01   |
| `read`                                                                                                   | Reserved call        | 01   |
| `open`, `drop`, `drag`                                                                                   | Default id           | 01   |
| `OPENSPOT_ID`, `OPENSPOT_REASON`, `OPENSPOT_DATA`, `OPENSPOT_SH`                                         | Environment variable | 01   |
| `openspot <noun> <verb>`, `openspot help <noun>`                                                         | Command              | 01   |
| `text`, `number`, `gauge`, `graph`, `picture`, `switch`, `slider`, `field`, `choice`, `option`, `hotkey`, `button`, `section`, `repeat`, `row` | Block kind | 01 |
| `view`                                                                                                   | Block kind           | 03   |
| `title`, `detail`, `icon`, `tone`, `value`, `color`, `look`, `align`                                     | Block key            | 01   |
| `parent`, `hides`, `keyword`, `shortcut`, `file`                                                         | Row key              | 01   |
| `grid`, `grid.<size>`, `main`, `title`, `detail`, `search`, `recents`, `toast`, `link`, `progress`, `select` | Head key | 01 |
| `end`                                                                                                    | Head key             | 05   |
| `call`, `reason`, `arg`, `stop`                                                                          | Stdin key            | 05   |
| `title`, `detail`, `size`, `grid`, `opens`                                                               | Widget key           | 01   |

The verbs and the row keys of each `openspot` noun, such as `screen` or `calendar`, are in `openspot help <noun>`.

## How to extend

An old script never sees a word that it did not ask for. To add a default id, a moment, a place, an environment variable
or a block kind, add one word to one spec and to the registry. A new `openspot` noun gets its guide in `app/Help`. An old app skips a key that
it does not know, and skips and reports a block that it does not know. A new default id reaches only a script that asks
for it.
