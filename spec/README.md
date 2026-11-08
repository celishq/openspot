# Openspot specs

These specs are the plugin contract of Openspot. Each one is a feature that a host can support or skip on its own, and
that an author can ignore. 00 and 01 are required.

The app joins `00` to `09` in order into one `GUIDE.md`, which the Build spot opens and copies for an AI. Edit the specs,
never the joined file. The rules of the app that no author sees are in `app/RULES.md`.

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
| [09 MCP](09-mcp.md) | draft | 01, 02 | An MCP server as a spot. |

## Rules for the specs

- Each rule has an ID, such as `C3`, that is unique across the specs. A commit, a test or a docstring can name it.
- A final spec does not change the meaning of a word. A new feature is a new word, or a new spec.
- A draft spec can change. It becomes final when a real use proves it.
- A spec holds decisions. How the app does them belongs in the code and its tests.

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
8. F10: a real MCP server, and its start time for each call.
