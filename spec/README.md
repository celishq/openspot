# Openspot specs

These specs are the plugin contract of Openspot. Each one is a feature that a host can support or skip on its own, and
that an author can ignore. 00 and 01 are required.

The build joins the numbered specs in order into one `GUIDE.md` inside the app, which the Build spot opens and copies
for an AI. The joined file is not in the repo. The rules of the app that no author sees are in `app/RULES.md`.

| Spec | Status | Needs | What it holds |
|---|---|---|---|
| [00 Guide](00-guide.md) | final | | How to write, check and word a plugin. |
| [01 Core](01-core.md) | final | | The format, the header, the calls, the frames, the moments and how long a call runs. |
| [02 Lists](02-lists.md) | final | 01 | Rows, search, actions and forms. |
| [03 Sheets](03-sheets.md) | final | 01 | Parts in a drawing. |
| [04 Triggers](04-triggers.md) | final | 01 | Drops and commands with keys. |
| [05 Stay](05-stay.md) | draft | 01 | A script that keeps running between calls. |
| [06 Metrics](06-metrics.md) | final | 01 | Live values in widgets and the menu bar. |
| [07 Capabilities](07-capabilities.md) | final | 01 | The `openspot` command. |
| [08 Sharing](08-sharing.md) | final | 01 | The `.spot` file. |

## How a spec is written

These rules come from the way Nostr writes its NIPs.

1. **One spec, one feature.** A host that skips a spec still works, and so does a script that ignores it. Only 00 and 01
   are required.
2. **The head.** A spec starts with its number and name, then its markers in backticks: `draft` or `final`, and
   `required` or `optional`. A line names the specs it needs.
3. **Only the contract.** A spec says what passes between a script and the host: the header, the arguments, stdin,
   stdout, the environment and the files. It does not say how the host draws, which keys the panel uses, or how the host
   is tuned. Each host chooses those, and `app/RULES.md` holds the choices of this app.
4. **A number only when a script needs it.** The 10 seconds of a `read` is in the spec, because a script must be fast
   for it. A delay that only the host feels, such as a cache or a kill timer, is not.
5. **The example first.** Show the wire format with one real example, then give the rules. A section that teaches more
   than the contract belongs in 00.
6. **Rules in the text.** Write each rule once, in the prose, with `must`, `should` or `can`. Do not repeat it in a table.
7. **Stable IDs.** A rule keeps an ID, such as `C3`, only when code, a test or another spec names it. Do not change or
   reuse an ID.
8. **Decisions.** A spec can end with a short table of decisions: a choice that later work must not break, with the
   rejected one. How the app does a decision belongs in the code and its tests.
9. **One way to do one thing.** A new spec does not give a second way to do what a spec already does.
10. **Each word in one spec.** A header key, a block kind, a default id, an environment variable and a capability are
    each defined in one spec, and the registry below names it.
11. **Final is final.** A draft can change. It becomes final when a real use proves it. A final spec does not change the
    meaning of a word: a new feature is a new word or a new spec. A word that is no longer good stays in the registry,
    struck through, with the word that replaces it.

## Registry

| Word | Kind | Spec |
|---|---|---|
| `name`, `symbol`, `subtitle`, `key`, `size`, `order`, `grid`, `read`, `data` | Header key | 01 |
| `rank` | Header key | 02 |
| `drop`, `command` | Header key | 04 |
| `stay` | Header key | 05 |
| `tray` | Header key | 06 |
| `sheet`, `panel`, a number, `launch`, `wake` | Moment of `read` | 01 |
| `toast`, `open` | Block kind | 01 |
| `row`, `action`, `field` | Block kind | 02 |
| `part`, `section` | Block kind | 03 |
| `end` | Block kind | 05 |
| `stop` | Block kind on stdin | 05 |
| `read` | Reserved word | 01 |
| `run`, `open`, `on`, `off`, `level` | Default id | 01 |
| `drop` | Default id | 04 |
| `OPENSPOT_REASON`, `OPENSPOT_DATA`, `OPENSPOT_SH` | Environment variable | 01 |
| `check`, `catalog`, `render`, `sandbox`, `color`, `clipboard`, `translate`, `emoji`, `symbols`, `window` | Capability noun | 07 |
| `.spot` | File | 08 |

## Goals

In order. An earlier goal wins when two goals conflict.

1. **A small plugin costs almost nothing.** One executable file. No build, no manifest, no account, no SDK.
2. **A plugin never draws in Openspot.** Openspot draws all that a script prints. A script can open its own Mac window.
3. **Nothing runs by surprise.** Openspot runs a script only when a person acts or when its header says so.
4. **A plugin has real power.** It can use any Mac API, hold long-lived state and stream a long process.
5. **A model can write a plugin.** The contract is small enough that a model writes a good plugin from the guide alone.

## How to extend

An old script never sees a word that it did not ask for.

| ID | To add | Do this |
|---|---|---|
| X1 | A default id | One row in Core. It reaches only a script that asks for it (C2). |
| X2 | A moment | One word for `read`, in one place in Core. |
| X3 | A value for a script | One environment variable. |
| X4 | A Mac feature | One `openspot <noun> <verb>` (07). |
| X5 | A part or a value to draw | One entry in the catalog. An old app skips the key (R2). |
| X6 | A kind of block | One first key. An old app skips the block (R10). |

## Open items

1. K2: how much of the speed of a kept translation helper comes from the kept session, and not from macOS.
2. P5: what macOS does when a compiled program under Openspot calls a protected API. It needs the person.
3. M3: whether each plugin still fits the time limits when reads run at the same time.
4. L11: whether 1 second is enough to stop a double press from stopping work.
5. D1, D2: a real drag over the menu bar item. An off-screen render proves the mark, and a test proves which cards take it.
6. Y2: a copy that Openspot ended still runs its calls for up to 4 seconds (Y4), so two copies can run for that time.
7. Y7: the running mark and the stop of a staying call, in the real panel.
