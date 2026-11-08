# Openspot specs

These specs are the contract between a plugin and Openspot. The build joins them in order into one `GUIDE.md` inside the
app, which the Build spot opens and copies for an AI. How the app itself works is in its code and in `app/RULES.md`.

| Spec                                    | Status | Needs | What it holds                                                                    |
| --------------------------------------- | ------ | ----- | -------------------------------------------------------------------------------- |
| [01 Core](01-core.md)                   | final  |       | The file, the format, the header, the moments, the calls and the life of a call. |
| [02 What a script prints](02-output.md) | draft  | 01    | Components, drawings, rows, repeats, buttons, cards and metrics.                 |
| [03 Views](03-views.md)                 | draft  | 01 02 | A plugin's own SwiftUI view in an area.                                          |

Specs 00 and 04 to 10 are gone. Their numbers are not used again.

## Goals

In order. An earlier goal wins when two goals conflict.

1. **A small plugin costs almost nothing.** One executable file. No build, no manifest, no account, no SDK.
2. **Openspot draws a plugin's data.** A script prints data, and Openspot draws it. A plugin can add its own SwiftUI
   view to its spot, and a script can open its own Mac window.
3. **Nothing runs by surprise.** Openspot runs a script only when a person acts or when its header says so.
4. **A plugin has real power.** It can use any Mac API, keep state in files and stream a long process.
5. **An LLM writes a working plugin.** With `GUIDE.md` alone, an LLM writes a plugin that passes `openspot check` and
   works on the first try.

## How a spec is written

These rules come from the way Nostr writes its NIPs.

1. **One spec, one feature.** A host that skips a spec still works, and so does a script that ignores it.
2. **The head.** The number and the name, then `draft` or `final`, and `required` or `optional`, then the specs it needs.
3. **Only the contract.** What passes between a script and the host: the header, the arguments, stdin, stdout and the
   environment. Not how the host draws, its keys or its timings, unless a script must be written for a number.
4. **The example first.** One real example, then the rules.
5. **Each rule once,** in the prose. A rule keeps an ID, such as `C3`, only when code or a test names it, and an ID is
   never changed or used again.
6. **A short table of decisions** at the end: each choice that later work must not break, with the one it rejected.
7. **One way to do one thing,** and each word in one spec, as the registry shows.
8. **Final is final.** A draft becomes final when a real use proves it. A final spec never changes the meaning of a word:
   a new feature is a new word or a new spec.

## Registry

| Word                                                                                                     | Kind                 | Spec |
| -------------------------------------------------------------------------------------------------------- | -------------------- | ---- |
| `title`, `icon`, `detail`, `shortcut`, `size`, `read`, `data`, `drop`, `command` | Header key           | 01   |
| `global`, `tray`                                                                                         | Header key           | 02   |
| `stay`                                                                                                   | Header key           | 04   |
| `end`                                                                                                    | Head key             | 04   |
| `call`, `reason`, `arg`, `stop`                                                                          | Stdin key            | 04   |
| `sheet`, `panel`, a number, `launch`, `wake`                                                             | Moment               | 01   |
| `toast`, `link`                                                                                          | Head key             | 01   |
| `text`, `number`, `gauge`, `graph`, `picture`, `spot`, `switch`, `slider`, `field`, `choice`, `hotkey`, `button`, `section`, `repeat`, `template`, `row` | Block kind | 02 |
| `view`                                                                                                   | Block kind           | 03   |
| `grid`, `grid.<place>`, `card`, `pad`, `main`                                                           | Head key             | 02   |
| `read`                                                                                                   | Reserved word        | 01   |
| `run`, `open`, `drop`                                                                                    | Default id           | 01   |
| `OPENSPOT_REASON`, `OPENSPOT_DATA`, `OPENSPOT_SH`                                                        | Environment variable | 01   |
| `OPENSPOT_STAY`                                                                                          | Environment variable | 04   |
| `openspot <noun> <verb>`                                                                                 | Command              | 01   |

## How to extend

An old script never sees a word that it did not ask for. To add a default id, a moment, an environment variable, an
`openspot` noun, a part or a block kind, add one word to one spec and to the registry. An old app skips a key or a block
that it does not know (R2, R10), and a new default id reaches only a script that asks for it (C2).
