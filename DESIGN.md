# Openspot design

This document is the spec of the plugin contract. It holds decisions only.

- When this document and the code differ, the code is wrong, or this document must change first.
- `app/Shell/GUIDE.md` teaches the contract to authors, with each key and example. It follows this document.
- `app/Shell/LOOK.md` holds the decisions about how the panel looks.
- Each rule has an ID, such as `C3`. A commit or a test can name it. Section 13 lists where the code differs today.

## 1. Goals

In order. An earlier goal wins when two goals conflict.

1. **A small plugin costs almost nothing.** One executable file. No build, no manifest, no account, no SDK.
2. **A plugin never draws in Openspot.** Openspot draws all that a script prints. A script can open its own Mac window.
3. **Nothing runs by surprise.** Openspot runs a script only when a person acts or when its header says so.
4. **A plugin has real power.** It can use any Mac API, hold long-lived state and stream a long process.
5. **A model can write a plugin.** The contract is small enough that a model writes a good plugin from the guide alone.

## 2. The contract

```text
<script> read [text]          safe: show what you have
<script> <id> [value]...      act: something happened to this id
values on stdin               frames of key=value blocks on stdout
```

1. **Format:** a line is `key=value`. A blank line ends a block. A line `---` ends a frame. `\n` and `\\` are the only
   escapes. The header is the same format, in comment lines.
2. **Kind:** the first key of a block names its kind. The app skips a kind that it does not know.
3. **Calls:** `read` is safe, and the app runs it at the moments the header lists. Any other call acts, and runs only when
   the person acts. An id is one that the script printed or listed, or a default id of the app.
4. **Life:** an exit ends a call. A press stops it. Only `stay=true` keeps a script running for more calls.

```sh
#!/bin/sh
# read=sheet
case "$1" in
  read) printf 'row=Today\nrun=today\n' ;;
  open) open -a Notes ;;
esac
```

| Noun | What it is |
|---|---|
| Plugin | One executable file in the plugins folder. Its header says what it is. |
| Spot | One card in the grid. A plugin gives at most one, and a widget gives one. |
| Sheet | What a spot opens in the panel: rows, or parts in a drawing. |
| Call | One run of a script, or one block to a script that stays. |
| Frame | One answer. A call can print many. |
| Capability | A Mac feature behind the `openspot` command. |

## 3. The app

| ID | Rule |
|---|---|
| A1 | One owner in Core starts each run of a script. A capability's helper and a shipped spot's tools are not scripts. |
| A2 | Each script has one sheet model in Core. It holds the last frame, the rows, the parts and the running calls, and each place that shows the script reads from it. A run of one script never stops a run of another. |
| A3 | A stopped run changes nothing. Only a call that ended by itself can report that there is nothing to show. |
| A4 | Search text stays until the person presses Esc. |
| A5 | Spots, Build, Settings, Updates and Quit ship with the app and answer the same calls, in Swift. |
| A6 | One global key opens the panel, and the person chooses it. A script never holds a key (P8). |
| A7 | The person arranges the grid in `config.toml`: order, `size`, `grid` and `enabled`. It wins over the plugin. A size is a preference, and the grid can change it to fill a row. |
| A8 | The app opens the panel unseen once as it starts, so that each `panel` read runs. It waits at most 2 seconds, then shows a toast that names the key. |
| A9 | A sheet with no answer yet holds its motion for at most 150 ms, so that it grows once, to its real size. |
| A10 | A dragged `.spot` file shows in the search field, and a drop, a paste or a double-click opens the install screen from there. |
| A11 | The core spots are the scripts in `plugins/` of this repo. They run in place from the app, so an update updates them. Nothing downloads. |
| A12 | A first launch turns on each core spot that reads only local data. Each other core spot is off until the person turns it on. A file in the plugins folder with the same ID wins over a core spot, and is always on. |
| A13 | Enter on a row of Spots turns that spot on or off, and keeps the panel open. |
| A14 | A first launch has no config and no plugin, opens the panel on the grid once, and does not open at login. |
| A15 | A toast takes no input, except a failure with a fix (R9). One fix key, which the person chooses, opens it, and only while the toast shows. |

## 4. The plugin file

| ID | Rule |
|---|---|
| F1 | A plugin is one executable file, in any language, at the top of the plugins folder or one folder down. |
| F2 | Openspot learns what a plugin is from its header. A scan never runs a script. |
| F3 | Openspot scans the folder each time the panel opens, so a new plugin needs no restart. |
| F4 | One file gives at most one spot. It can offer many actions, which it prints. |
| F5 | The ID of a plugin is its path with no extension, such as `home/coffee`. |
| F6 | A header key that is not valid refuses that plugin. Openspot reports why and loads the others. |
| F7 | A script with a number in its `read` and no `key` has no spot. A widget or the menu bar can show it. |
| F8 | Widgets are in a `.toml` file, because a person writes them by hand. A widget runs nothing. |
| F9 | The header gives `grid`, `size` and `order`. With `panel` in its `read`, the head of a frame can change them, and a frame with no such key keeps the header's value. `config.toml` wins over both (A7). |
| F10 | A script with `mcp=true` is an MCP server on stdio. Its tools are actions, and its resources are rows. A scan never starts it. |

## 5. Calls

| ID | Rule |
|---|---|
| C1 | `read` is the only reserved word. `run`, `open`, `drop`, `on`, `off` and `level` are default ids: the app's own events. A part cannot use a default id, and an action can use only `open`, to change it. `openspot check` reports a clash. |
| C2 | A new default id reaches only a script whose header or output asks for it. |
| C3 | A form is the same call twice: first with empty stdin, when the script prints its fields, then with the values on stdin. |
| C4 | Openspot waits for a pause before it sends a change of text or of a slider. |
| C5 | Text that the person types stays as typed until they press something. |
| C6 | A value too long for the arguments goes on stdin only. |
| C7 | Presses of the keys of one script run one at a time and in order. A press of a key never stops a call. |

### Moments

| ID | Rule |
|---|---|
| M1 | A script has one read at a time. A new request joins the read that runs. |
| M2 | A `panel` or `sheet` moment takes an answer younger than 5 seconds. A change, a number, `launch` and `wake` always read. |
| M3 | Reads run at the same time. The panel never waits for one script. A spot shows its header until its answer arrives. |
| M4 | After a call that shows no state, Openspot reads the script once. |
| M5 | A read must be safe at each moment that its header lists. Only its author can promise this. |
| M6 | A read gets `OPENSPOT_REASON`: `panel`, `sheet`, `timer`, `launch`, `wake`, `search` or `change`. |

### Drops

| ID | Rule |
|---|---|
| D1 | A drag over the Openspot item in the menu bar opens the panel with no change of focus, until the drag ends. |
| D2 | During a drag, each card whose `drop` takes every dragged file shows it, and only such a card takes the drop. |
| D3 | A drop is one `drop` call, with each path as its own argument, and it closes the panel. |
| D4 | A drop on a card with a running call waits for that call. It does not stop it. |
| D5 | A click on a card with `drop` and no sheet opens a file chooser, and the choice runs the same call. |
| D6 | A `drop` call runs as any other call does (section 7). |

### What a script receives

| ID | Rule |
|---|---|
| W1 | Arguments hold the id and its values. Stdin holds what the person filled in, as one block. `OPENSPOT_DATA` names a folder for its files, and `data=<name>` shares one. `OPENSPOT_SH` names an optional shell helper with `esc` and `value`. `PATH` has the `openspot` command first. |

## 6. Frames

| ID | Rule |
|---|---|
| R1 | What a script prints decides how its spot shows: rows, actions or parts make a list, `level` a slider, `on` a toggle. |
| R2 | A line with an unknown key is skipped. |
| R3 | Exit 0 is success. Any other code is a failure, and the last line on stderr shows to the person. |
| R4 | Printing nothing means that there is nothing to show. |
| R5 | `toast` shows at once, also with the panel closed. |
| R6 | `search=script` sends each search change to the script as `read <text>`. Otherwise Openspot searches the rows. |
| R7 | `recents=false` does not sort recent picks first. |
| R8 | A stop can come at any time, and two calls can run at once, so a script never leaves a file half written. |
| R9 | A failure can print `open=<url>`, the place that fixes it, and the fix key opens it (A15). |
| R10 | The kinds are `row`, `action`, `field`, `part`, `section`, `toast`, `open` and `end`. The first block with another first key is the head. A later one is skipped, and `openspot check` reports it. |
| R11 | `toast` and `open` can be keys of the head, or blocks of their own at any place. |
| R12 | Openspot reads OSC 9;4 as the progress `value` and OSC 9 as a `toast`, in any output, and removes each other escape code. A code never makes the app act. |
| S1 | A line `---` ends a frame, and so does the end of the output. Openspot draws each frame at once. Any call can stream. |
| S2 | A frame with a layout replaces the sheet. A frame with only parts changes those parts. |
| S3 | A frame with no open sheet shows only its `toast` and its state. Openspot keeps the last frame for the sheet. |

### Layout

| ID | Rule |
|---|---|
| B1 | A sheet draws its layout with `grid=` lines. There are no named layouts. |
| B2 | The words of a `grid=` line set the columns, so there is no width to set. |
| B3 | Each row has one height and each gap one size, and the app owns both. |
| B4 | Rows that hold text, a picture, a chart, a list or a repeated area share the free height. |
| B5 | `repeat=<letter> <per line>` flows the rows into one area, which scrolls. |
| B6 | A complex view is a Swift block in the app, which a script names and fills with data. |

## 7. How long a call runs

| ID | Rule |
|---|---|
| L1 | A `read` has 10 seconds until its first frame or its end, and it stops when nothing wants it. |
| L2 | Any other call has no time limit. It keeps running with the sheet and the panel closed. |
| L3 | Something wants a script while its open sheet shows, while the open panel shows it in a widget or reads it at `panel`, while the menu bar shows it, or at all times with `launch` in its `read`. |
| L4 | A new value for a part stops the older call of that part, and only the newest answer shows. |
| L5 | A second press of a running part, action or card stops its call: terminate to its group, and kill 2 seconds later. |
| L6 | A call that runs 1 second shows on its part, its action, its spot and the menu bar item, so the person can find and stop it. A call to a staying script shows only by Y7. |
| L7 | When a sheet opens, Openspot reads, then adds the last frame of each running call. |
| L8 | The end of a call shows its `toast`. A failed call always tells the person. A failed timer read only dims the last value. |
| L9 | Quitting Openspot stops each call. |
| L10 | A call ends when its output closes. |
| L11 | A press within 1 second of the start of a call does nothing, so a double press does not stop it. |
| G1 | A running call shows a ring from the `value` of its last frame, or a spinner with no `value`. |
| G2 | The menu bar item shows the oldest running call and how many run. |
| G3 | A click on that item opens the panel with that spot selected. |
| G4 | A frame's `title` and `detail` show on the spot only while its call runs. |
| G5 | A sheet of parts can show a part with `block=progress`. |

## 8. Long-lived state

A plugin keeps state in this order of preference: files in `OPENSPOT_DATA`, a capability that stays loaded, or `stay=true`.

| ID | Rule |
|---|---|
| K1 | A capability is `openspot <noun> <verb>`. It works the same from a script and from a terminal. |
| K2 | A capability with state keeps it in a helper. The helper starts at the first call, and exits after 30 seconds with no call. |
| K3 | A script never starts, finds or stops a helper, and the app does not track it. |
| K4 | A capability prints `status=<word>` when it cannot answer. |
| K5 | Closing the panel closes a sheet of parts and drops its values. A sheet of rows stays open. |
| Y1 | A staying script gets one block on stdin for each call: `name`, `value`, `field.<id>` for each value of the sheet, and `id`. |
| Y2 | Each call reaches the running script. No call starts a second copy. |
| Y3 | A staying script starts when something first wants it (L3). |
| Y4 | To end it, Openspot closes its stdin, then terminates its group after 2 seconds and kills it 2 seconds later. |
| Y5 | If it ends and something still wants it, the next call starts it again. After 3 failures in one minute, it waits for a changed file, and the person is told. |
| Y6 | Openspot can stop a staying script at any time. What must survive goes in `OPENSPOT_DATA`. |
| Y7 | Once a script has printed one `end=<id>`, each later call runs until its own `end`, and the script keeps running for it. A second press sends `stop=<id>`. |

A capability is added only when macOS has no command for it, when it needs a usage text in the app, or when it needs state
between calls. `app/Shell/GUIDE.md` lists each one.

## 9. Widgets and the menu bar

| ID | Rule |
|---|---|
| H1 | A widget or the menu bar can show any script with a `read`, by its ID. A failed read keeps the last value, dimmed. |
| H2 | A widget places metrics in a named layout or a `grid` drawing. Each place takes its form from the room of its cell. |

## 10. Security

| ID | Rule |
|---|---|
| P1 | A plugin runs with the full access of the person. There is no sandbox. |
| P2 | So a header cannot grant or deny power, and there is no `uses` key. |
| P3 | Nothing runs on a scan (F2). |
| P4 | Before a person installs a shared spot, Openspot shows all the text it can, says what runs by itself and names each file that it cannot show. Only a modified key installs it. |
| P5 | Each usage text for a protected Mac feature is in the app, so a protected feature is a capability. |
| P6 | A `.spot` file can carry a compiled program, and the review says first that no one can read it. "Copy to share" compiles a Swift script into `<name>.program` beside its source, and the program runs in its place. |
| P7 | A `.spot` file has no signature. Openspot warns the sender about secrets, and does not look for them. |
| P8 | Only a command that a header lists can have a key, and only the person assigns it. |
| P9 | A core spot needs no review, because it is signed with the app. |

## 11. How to extend

An old script never sees a word that it did not ask for. A new meaning for an old word is a breaking change.

| ID | To add | Do this |
|---|---|---|
| X1 | A default id | One row in Core. It reaches only a script that asks for it (C2). |
| X2 | A moment | One word for `read`, in one place in Core. |
| X3 | A value for a script | One environment variable. |
| X4 | A Mac feature | One `openspot <noun> <verb>`. |
| X5 | A part or a value to draw | One entry in the catalog. An old app skips the key (R2). |
| X6 | A kind of block | One first key. An old app skips the block (R10). |

## 12. Decisions

| Decision | Why | Rejected |
|---|---|---|
| The app's events are default ids, and `read` is the only reserved word | A model writes `case "$1" in` with one branch for each id. A default id is one more branch, with no verb to learn. | A verb for each kind of call, such as `pick`, `set` and `do`. |
| The first key names the kind | A model and a person see what a block is from its first line, and a new kind is one new key. | A kind found from any key of a block. |
| A staying script says so in its header | A normal script reads stdin to its end, so the app must close stdin before the answer. | The app keeps any process that stays alive after `end=<id>`. |
| A stop is the block `stop=<id>` | No name of a part or an action can clash with it. | `name=stop`. |
| Escape codes report and never act | A script can print text from the web, and printed text must not open a link. | OSC 8 as `open`. |
| A script lists commands, and the person gives them keys | A key depends on the person's hands and apps, and the config holds each key in one place. | A `global` key in the header. |
| A failure links its fix, and one key opens it | The script knows the fix, so the app guesses nothing, and the key works with no mouse. | Reading the error text for a known fix. |
| Scripts, not a JS runtime | Shell gives each Mac tool at once, and a start costs about 5 ms. JS can come later as one more executable. | JS only. |
| Lifetime from rules | A person can see and stop work, so work needs no limit and no key. | A `job` key. A lifetime value. |
| Hooks are moments of `read` | Each need so far is a refresh at a moment, and `stay=true` covers the rest. | A `hook` call. |
| State behind a capability | A script stays a handler, with no fifo and no server. | A server in each plugin. |
| Streaming needs no key | A long call only prints more. | A stream mode. |
| A sheet is a drawing, with one row height | A model writes one form, and each result stays even. | Named layouts, ratios and nested drawings. |
| Complex views are Swift blocks in the app | The text language stays small, and a plugin never draws in Openspot. | A view in a plugin now. |
| Header in each file, no manifest | Goal 1, and a scan runs nothing. | A manifest. |
| No permission model | A script can already do all that the person can. A false limit is worse than none. | A `uses` key. |
| A spot travels as a `.spot` file of JSON: a format number and its files | A chat takes a file of any size, any editor shows JSON, and the header already holds each fact. | Encoded text, a zip, a link. |
| A shared file of the same path replaces the old one, which goes to the Trash | A new name would break the IDs that a widget places. | A new name for each clash. |
| Core spots run in place from the app, from `plugins/*.sh` | A first run needs no network, an update updates them, and a diff shows the changed line. | A download, a copy at first launch, `.spot` files in the repo. |

## 13. Where the code differs today

The code follows this document.

## 14. Open items

1. K2: how much of the speed of a kept translation helper comes from the kept session, and not from macOS.
2. P5: what macOS does when a compiled program under Openspot calls a protected API. It needs the person.
3. M3: whether each plugin still fits the time limits when reads run at the same time.
4. L11: whether 1 second is enough to stop a double press from stopping work.
5. D1, D2: a real drag over the menu bar item. An off-screen render proves the mark, and a test proves which cards take it.
6. Y2: a copy that Openspot ended still runs its calls for up to 4 seconds (Y4), so two copies can run for that time.
7. A11: whether notarization and Gatekeeper accept the scripts in the app. Only a published release proves it.
8. F10: an MCP server starts once for each call. A real server and its start time are not measured.
