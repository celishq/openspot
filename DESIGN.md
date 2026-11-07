# Openspot design

This document is the spec. It says how Openspot works and how plugins talk to it.

- When this document and the code differ, the code is wrong, or this document must change first.
- `app/Shell/GUIDE.md` teaches the same contract to plugin authors. It follows this document.
- Each rule has an ID, such as `C3`. A commit or a test can name it.
- Section 13 lists where the code differs today. Section 15 lists what is not decided or not proven.

To align the code: read this document, read the code of each module that section 13 names, make the change with a test
first, and remove the row from section 13. A choice that this document does not cover goes to the person first.

The examples show the target contract. They are sketches, and the app does not run them yet.

## 1. Goals

In order. An earlier goal wins when two goals conflict.

1. **A small plugin costs almost nothing.** One executable file. No build, no manifest, no account, no SDK.
2. **A plugin never draws in Openspot.** Openspot draws all that a script prints. So each plugin looks right. A script can also open its own Mac window, which is its own (goal 4).
3. **Nothing runs by surprise.** Openspot runs a script only when a person acts or when the header of the script says so.
4. **A plugin has real power.** It can use any Mac API, hold long-lived state and stream a long process.
5. **A model can write a plugin.** The contract is small enough that a model can write a good plugin from this text alone.

The model for the API is Cloudflare Workers: one file, one call shape, stateless code, a response that can stream, and
state behind a binding. Section 14 says where this model stops.

## 2. The contract

This is all of the plugin API:

```text
<script> [name] [value]     values on stdin     frames on stdout
```

> A moment or a person's act makes a call. The script prints frames. Openspot draws the frames.
> The script holds no state. It keeps state in a file, or behind the `openspot` command.
> Only `stay=true` keeps a script running.

```sh
#!/bin/sh
# read=sheet
case "$1" in
  read)   list-rows "$2" ;;
  open)   open "$2" ;;
  copy)   printf %s "$2" | pbcopy ;;
  encode) encode-with-frames ;;
esac
```

**The nouns**

| Noun | What it is |
|---|---|
| Panel | The window that the trigger key opens. It holds the search field and the grid. |
| Spot | One card in the grid. A plugin file gives at most one spot, and a widget gives one spot. |
| Sheet | What a spot opens in the panel: rows, or parts in a layout. |
| Plugin | One executable file in the plugins folder. |
| Header | The comment lines at the top of a plugin. They say what it is called and when it runs. |
| Call | One run of the script, or one event to a script that stays. |
| Frame | One answer: blocks of `key=value` lines. A call can print many frames. |
| Capability | A Mac feature that Openspot offers through the `openspot` command. |

## 3. The app

- **Core** holds the contract and all logic: the scan, the calls, the runs and the sheet model. It imports neither AppKit
  nor SwiftUI.
- **Shell** holds windows and drawing, and the `openspot` command with the Mac features that need AppKit or a framework.
- **The panel** shows the grid. The search field filters the spots and the rows of each list that has a `rank`.
- **The menu bar** shows each script that has `tray=true`.
- **The sandbox window** shows a sheet from text, a file or a script. It uses the same code as the panel.

| ID | Rule |
|---|---|
| A1 | One owner in Core starts each run of a script. No other code starts a script. A capability's helper and a shipped spot's tools are not scripts. |
| A2 | Each script that shows anything has one `SpotSheet` in Core. It holds the last frame of the script, its rows, its parts, its open state and its running calls. The card, the sheet, a widget and the menu bar all read from it, and no other place keeps what a script printed. A run of one script never stops a run of another. |
| A3 | A stopped run changes nothing. Only a call that ended by itself can report that there is nothing to show. |
| A4 | Search text stays until the person presses Esc. |
| A5 | Plugins, Settings and Updates ship with the app. Each answers the same calls, in Swift. Updates has `grid=false`, and prints `grid=true` when a downloaded update waits to install. It takes the first place of order 0, so its card shows with no scrolling. |
| A6 | One global key opens the panel from any app, and the person chooses it. The person can also give a key to a command that a script lists in its header. A script never holds a key. |
| A7 | The person arranges the grid: each `[[spots]]` table of `config.toml` names a spot by `id`, and can set `size` and `grid`. It overrides the plugin. A `size` is a preference, and the grid can still change it to fill a row. Listed spots take the order of the file. The Edit Spots mode writes this file. |
| A8 | The app opens the panel unseen once as it starts, which runs each script with `panel` in its `read` and each script a widget places, and draws the panel. It waits for at most 2 seconds, then closes it and shows the toast "Openspot is ready". A script with only `sheet` in its `read` does not run. A press of the key in that time opens the panel at once. |
| A9 | A sheet that moves out of its card and has no answer yet holds that motion for at most 150 ms for the first answer, so that it grows once, to its real size. A sheet with an answer moves at once. A sheet that still waits after that shows no search field, and its first answer sets its size on the same motion. |
| A10 | A dragged `.spot` file shows in the search field as an icon and a name, laid out as a sheet's header, and the grid stays. A drop, a paste or a double-click expands the field into the install screen, on the spring of a sheet, with the icon and the name in place, and pushes the grid as far as its lower edge moves. It closes back into the field. |

## 4. The plugin file

```sh
#!/bin/sh
say hello
```

This is a complete plugin. It is a spot called Hello, and a click runs it.

| ID | Rule |
|---|---|
| F1 | A plugin is one executable file, in any language, at the top of the plugins folder or one folder down. |
| F2 | Openspot learns what a plugin is from its text. A scan never runs a script. |
| F3 | Openspot scans the folder each time the panel opens, so a new plugin needs no restart. |
| F4 | One file gives at most one spot. It can offer many actions, which it prints. |
| F5 | The ID of a plugin is its path with no extension, such as `coffee` or `home/coffee`. |
| F6 | A header key that is not valid refuses that plugin. Openspot reports the reason and loads the others. |
| F7 | A script with a number in its `read` and no `key` has no spot. A widget or the menu bar can show it. |
| F8 | Widgets are in a `.toml` file, because a person writes them by hand. A widget runs nothing. |
| F9 | `grid=false` keeps a spot off the grid. It differs from F7: search and its key still find the spot. A script with `panel` in its `read` can print `grid=true` or `grid=false` to change this, and a frame with no `grid` keeps the header's value. A stopped call changes nothing. |

### Header

Comment lines right under the first line, one `key=value` on each line. They can start with `#`, `//` or `--`.

**What it looks like**

| Key | Values | Meaning |
|---|---|---|
| `name` | Text | The title. The default comes from the file name. |
| `symbol` | SF Symbol | The mark. |
| `subtitle` | Text | The second line. |
| `key` | One letter | Runs it after the trigger key. |
| `size` | `wide`, `small`, `square`, `strip`, `large` | A preference. The grid fills each row. |
| `order` | Number | Its place in the grid. |
| `grid` | `false` | The spot is not on the grid. Search and its key still find it. |

**How it behaves**

| Key | Values | Meaning |
|---|---|---|
| `read` | A list of `panel`, `sheet`, `launch`, `wake` and seconds | The moments when Openspot calls `read`. Section 5. |
| `rank` | Number | Its rows join the main search. Needs `panel`, `launch` or a number in its `read`. A number also needs a `key` (F7), or the plugin is refused. |
| `tray` | `true` | Shows it in the menu bar. Needs a number in its `read`, or `stay=true`. |
| `stay` | `true` | The script stays running. Section 8. |
| `drop` | A list of file extensions, `folder` or `*` | Its card takes files that a person drops. Section 5. |
| `command` | An ID and a title, such as `left:Left side`. One line for each command. | A command that a person can give a key in Settings. A press in any app runs `<script> <id>`, with no panel. |

A file with no header key has one call: `<script>`, on a click.

## 5. Calls

**The name.** The first argument is `read`, or a name.

- `read` is the only reserved word. It asks the script to print.
- Each other name is one that the script printed, such as an action or a part, or one of the built-in names below.
- With no `read` in its header, a script with no output of its own gets `<script>` with no argument on a click.

| When | Call | Stdin |
|---|---|---|
| A moment in `read`, or a sheet opens | `read` | Values of the open sheet, if any |
| The person types, and the script printed `search=script` | `read <text>` | None |
| A click on a card with no sheet, and a `read` in its header | `run` | None |
| A click on a toggle | `on`, `off` | None |
| A move of a slider on a card | `level <number>` | None |
| A pick of a row | `open <run>` | None |
| A key recorded on a row that has `shortcut` | `<run> <key>` | None |
| An action | `<action> [run]` | Form values, if any |
| A change of a part | `<part> <value>` | Values of the sheet |
| A press of a part | `<part>` | Values of the sheet |
| A drop of files on a card | `drop <path> [path]...` | None |
| A press of a key that a person gave a command | `<id>` | None |

| ID | Rule |
|---|---|
| C1 | A plugin cannot print a part or an action called `read`. `openspot check` reports it. |
| C2 | A new built-in name reaches only a script whose header or output asks for it. |
| C3 | An action with `form=true` first runs as `<action> [run]` with empty stdin, and the script prints `field` blocks. After the person fills the form, the same call runs with the values on stdin. |
| C4 | Openspot waits for a pause before it sends a change: 300 ms for text, also for `read <text>`, and 100 ms for a slider. |
| C5 | Text that the person types stays as typed until they press something. |
| C6 | A value over 64 KB is left out of the arguments, because the system limits them to about 1 MB. Stdin still holds it: a value of the sheet as it is, and any other value under the key `value`. |
| C7 | Presses of assigned keys of one script run one at a time and in order. A press never stops a call, so fast presses all count. |

### Moments

| Moment | Means |
|---|---|
| `launch` | The app starts. |
| `wake` | The Mac wakes. |
| `panel` | The panel opens, and once when the app starts (A8). |
| `sheet` | Its sheet opens. A spot with a sheet does this with or without the word. |
| A number | Every that many seconds, while something wants it (L3). |

| ID | Rule |
|---|---|
| M1 | A script has one read at a time. A new request for a read joins the read that runs. |
| M2 | A read that a `panel` or a `sheet` moment asks for uses an answer that is younger than 5 seconds. A read after a change of state does not. A read from a number in `read`, from `launch` or from `wake` always runs, so `read=1` shows a value that is 1 second old. |
| M3 | Reads run at the same time. The panel never waits for one script. A spot shows its header until its answer arrives. |
| M4 | After a call with no frame, or with frames that show no `on`, `level` or part, Openspot reads a script that has a `read` key once, by M1. |
| M5 | A read must be safe at each moment that its header lists. Only the author of the header can promise this. |

### Drops

```sh
#!/bin/sh
# name=To MP4
# symbol=film
# drop=mov,mkv,avi,webm
case "$1" in
  drop)
    shift
    for file; do encode-with-frames "$file"; done
    printf 'toast=Done\n'
    ;;
esac
```

| ID | Rule |
|---|---|
| D1 | A drag over the Openspot item in the menu bar opens the panel with no change of focus. The panel stays open until the drag ends. |
| D2 | For the whole drag, each card whose `drop` accepts each dragged file shows that it does, and only such a card takes the drop. Other cards do not change. |
| D3 | A drop runs one `drop` call with each path as its own argument, and closes the panel. |
| D4 | A drop on a card with a running call waits, and runs when that call ends. It does not stop the call. |
| D5 | A click on a card with `drop` and no sheet opens a file chooser, and the choice runs the same call. |
| D6 | A `drop` call follows section 7, as any other name does. |

### What a script receives

| Channel | Holds |
|---|---|
| Arguments | The name and its value. |
| Stdin | What the person filled in: all values of the sheet, or the fields of a form, as one block. Otherwise empty. |
| `OPENSPOT_DATA` | The folder for its files, which Openspot creates: `<config>/data/<spot>`. A script in a plugin folder uses the name of that folder. `data=<name>` in the header shares a folder with other spots. It prevents a clash, and it does not protect a file (P1). |
| `OPENSPOT_SH` | A shell file that a script can load. It is optional (W1). |
| `PATH` | The person's path, with the `openspot` command first. |

The rest of the environment comes from the app. In a value, a new line is `\n` and a backslash is `\\`.

| ID | Rule |
|---|---|
| W1 | `. "$OPENSPOT_SH"` gives a shell script two functions: `esc <text>` writes text as a value, and `value <id>` prints the real text of one value from stdin. Loading the file starts `cat` once to read all of stdin, so each `$(value id)` works in its subshell, and a script that loads it reads stdin only through `value`. Up to 1 KB, each function starts no program. Above that, it starts `sed`, `tr` or `awk`, and it finishes 1 MB in under 1 second. A staying script keeps its stdin for its calls: `OPENSPOT_STAYS` is set for it, so loading reads nothing and `value` prints nothing. The contract does not need them. |

```sh
. "$OPENSPOT_SH"
input=$(value input)
printf 'row=%s\n' "$(esc "$name")"
```

## 6. Frames

A script prints plain text. Each line is `key=value`, and a blank line ends a block.

| A block has | It is |
|---|---|
| `row` | A row of a list. |
| `action` | An action. `action=open` sets the word for Enter on a row. |
| `field` | A form field. |
| `part` | A part of a sheet. |
| `section` | A new group of parts. |
| Anything else, first | How the spot itself looks: `title`, `detail`, `on`, `level`, `grid`, `toast`, `search`, `recents`, a layout. |

| ID | Rule |
|---|---|
| R1 | What a script prints decides how its spot shows: rows, actions or parts make a list; `level` a slider; `on` a toggle. |
| R2 | A line with an unknown key is skipped. |
| R3 | Exit 0 is success. Any other code is a failure, and the last line on stderr shows to the person. |
| R4 | Printing nothing means there is nothing to show. After a change or a press, it asks for a new `read`. |
| R5 | `toast=<words>` shows at once, also with the panel closed. |
| R6 | `search=script` makes each search change call `read <text>`. Otherwise Openspot searches the rows itself. |
| R7 | `recents=false` does not sort recent picks first. |
| R8 | A script writes a file to a temp name, then moves it. A stop can come at any time, and two calls of one script can run at the same time, so a file must never be half written. |

### Streaming

Any call can stream. No key is needed. This is the normal path for a download or `ffmpeg`.

```sh
ffmpeg -i "$input" -progress pipe:1 "$output" | while read -r line; do
  case "$line" in
    out_time_ms=*) printf 'part=bar\nblock=progress\nlevel=%s\n---\n' "$(percent "$line")" ;;
  esac
done
```

| ID | Rule |
|---|---|
| S1 | A line `---` ends a frame, and so does the end of the output. Openspot draws each frame at once. |
| S2 | A frame with a layout replaces the sheet. A frame with only parts changes those parts. |
| S3 | A frame with no open sheet shows only its `toast` and its state. Openspot keeps the last frame for the sheet. |

### Layout

A sheet is a drawing and parts. A person or a model says what goes where, and the app sets each size.

| ID | Rule |
|---|---|
| D1 | A sheet draws its layout with `grid=` lines. A sheet has no named layouts. The catalog holds drawings to copy. |
| D2 | The words in a `grid=` line set the columns. A wider area takes more words, so there is no width to set. |
| D3 | Each row has one height and each gap has one size, and the app owns both. A taller area takes more lines. |
| D4 | Rows that hold text, a picture, a chart, a list or a repeated area share the free height. Other rows keep their height. |
| D5 | `repeat=<letter> <per line>` flows the rows of a script into one area of the drawing, and that area scrolls. Rows keep one list path for search, keys and selection. |
| D6 | A complex view is a Swift block in the app, which a script names and fills with data. A plugin still never draws in Openspot. |

## 7. How long a call runs

Two rules decide each call, with no key.

| Call | Runs until | Time limit |
|---|---|---|
| `read` | It ends, or nothing wants it | 10 s until its first frame or its end |
| Any other name | It ends, or the person stops it, or the rule of a change stops it | None |

| ID | Rule |
|---|---|
| L1 | A `read` stops when nothing wants it. So a stream from a `read` stops when its sheet closes. |
| L2 | A call that does work keeps running with the sheet and the panel closed. Openspot keeps its last frame. |
| L3 | Something wants a script while its sheet is open and the panel is open, while the panel is open and a widget places it or `panel` is in its `read`, while the menu bar shows it, or at all times with `launch` in its `read`. |
| L4 | A new value for a part stops the older call of that part, and only the newest answer shows. So typing does not pile up runs. |
| L5 | A second press of a running part, action or card stops the call. Each process in its group gets the terminate signal. After 2 seconds, Openspot kills each process in the group that still runs. |
| L6 | Running work shows on its part, its action, its spot and the Openspot item in the menu bar, so the person can find and stop it. It shows only after the call has run for 1 second, so a quick call does not flash. A call to a staying script shows no running mark, because Openspot cannot see where such a call ends. That script says what it does in its own frames. |
| L7 | When a sheet opens, Openspot does its `read`, then adds the last frame of each running call. |
| L8 | The end of a call shows its `toast`. A failed call always tells the person. |
| L9 | Quitting Openspot stops each call. To outlive the app, a script starts its work with `nohup` and then exits. A stop reaches the whole group, so `nohup` does not protect a child while its script still runs. |
| L10 | A call ends when its output closes. A script that leaves a child running sends the output of that child somewhere else. |
| L11 | A press within 1 second of the start of that call does nothing, so a double press does not stop it. |

### Progress

A call that does work reports its progress with the values that a metric prints. There is no other key.

```text
title=42%
value=0.42
detail=2 min left

---
```

| ID | Rule |
|---|---|
| G1 | While a call that does work runs (L6), its spot shows a ring from `value`. With no `value`, it shows a spinner. |
| G2 | While a call that does work runs (L6), the Openspot item in the menu bar shows a ring from the `value` of the oldest running call, or a spinner with no `value`. With more than one call, it also shows how many run. |
| G3 | A click on that item opens the panel with the spot of the oldest running call selected. |
| G4 | A frame's `title` and `detail` show on the spot only while the call runs. When the call ends, the spot shows its own state again. |
| G5 | A sheet of parts can also show a part with `block=progress`. |

## 8. Long-lived state

There are two levels for an author. A plugin uses the lower one when it can.

| Level | The script | State | Use it for |
|---|---|---|---|
| Handler | Runs once for each call | Stdin, files, and capabilities that stay loaded | Almost each plugin |
| Stay | Keeps running | Its own memory | A socket, a file watcher, a compiled program |

### Capabilities

A capability is `openspot <noun> <verb>`. It reads text on stdin and prints blocks. It is the binding of this design.

Add a capability only when one of these is true:

- macOS has no command for it. When macOS has one, such as `pbcopy`, `open`, `mdfind` or `shortcuts run`, a script uses it.
- It needs a usage text in the app, such as Calendar.
- It needs state that stays loaded between calls.

| ID | Rule |
|---|---|
| K1 | A capability works the same from a script and from a terminal. |
| K2 | A capability with state keeps it in a helper process. The helper starts at the first call, and exits after 30 seconds with no call. |
| K3 | A script never starts, finds or stops the helper, and the app does not track it. The way that a call reaches it is not part of the contract. |
| K4 | A capability prints `status=<word>` when it cannot answer, such as `status=missing`. |
| K5 | Closing the panel closes a sheet of parts and drops its values. The next open does a new `read`. A sheet of rows stays open. |

`Translate` is the reference. It is a handler with `read=sheet`. Each change runs the script, the script calls
`openspot translate`, and the language stays loaded for the next text. Closing the panel drops the text (K5). The language
leaves memory 30 seconds after the last text (K2).

### Stay

`stay=true` keeps a script running while something wants it (L3). It takes each call as one block on stdin, with a blank
line after it, and it prints frames at any time.

```text
name=input
value=Hello

```

| ID | Rule |
|---|---|
| Y1 | The block holds `name`, `value`, and one `field.<id>` for each value that stdin holds in a normal call. A `drop` has one `value` line for each path. |
| Y2 | Each call reaches the running script. No call starts a second copy of it. |
| Y3 | A staying script starts when something first wants it. A sheet shows with its first frame. |
| Y4 | To end a script, Openspot closes its stdin. Calls sent before that still run. After 2 seconds its group gets the terminate signal, and 2 seconds after that Openspot kills what still runs. |
| Y5 | If a staying script ends and something still wants it, the next moment or call starts it again. After 3 failures in one minute, Openspot does not start it again until the next scan that finds it changed, and it tells the person. |
| Y6 | Openspot can stop a staying script at any time. What must survive goes in `OPENSPOT_DATA`. |

## 9. Widgets and the menu bar

- A widget or the menu bar can show any script with a `read`, by its ID. It shows the value that the script prints.
- When a read fails, the last value stays and dims.
- A widget places scripts in a named layout or in a `grid` drawing. Each place takes its form from the room of its cell.
- `app/Shell/GUIDE.md` and `openspot catalog` hold the whole language of values, parts and layouts. This document does not repeat them.

## 10. The `openspot` command

The command is on the path of each script. It also gives the tools for authors.

| Call | Does |
|---|---|
| `openspot check [folder]` | Reports the faults of a plugins folder. |
| `openspot check --sheet` | Reports the faults of a sheet on stdin. |
| `openspot catalog` | Prints the sheet language. |
| `openspot render <file.png>` | Draws the sheet on stdin to a picture. |
| `openspot sandbox [file]` | Opens a window to try a sheet from text, a file or a script. |
| `openspot color pick` | Capability: the colour the person picks. |
| `openspot translate` | Capability: translates text on this Mac, and keeps each pair of languages loaded (K2). |
| `openspot translate languages` | Capability: the languages it knows. |
| `openspot emoji [--tone name]` | Capability: each emoji with its name in the language of the Mac, as rows. |

## 11. Security

| ID | Rule |
|---|---|
| P1 | A plugin runs with the full access of the person. The app has no sandbox, and a script is not limited to capabilities. |
| P2 | So a header cannot grant or deny power. A `uses` key would be only a label, and this design does not have one. |
| P3 | Nothing runs on a scan (F2). A script runs only by a person's act or by a key in its text. |
| P4 | Before a person installs a shared spot, Openspot shows all the text it can, says what runs by itself and names each file it cannot show. Only a modified key installs it. |
| P5 | Each usage text for a protected Mac feature is in the app. So a protected feature is a capability. |
| P6 | A compiled program travels in a `.spot` file, and the review says first that no one can read it. A plugin can be any executable (F1), so sharing takes each of them. |
| P6a | "Copy to share" compiles a Swift script into a universal `<name>.program` beside its source, so that only the sender needs the Swift tools. A scan lists no `.program` file, the source gives the header, and the program runs in place of the source. The review says that the two may not match. |
| P7 | A `.spot` file has no signature and names no sender. Openspot warns the sender about secrets, and does not look for them. |
| P8 | A spot cannot take a key by itself. Only a command that its header lists can have a key, and only the person assigns it. |

## 12. How to extend

Each extension has one place. An old script never sees a word that it did not ask for.

| ID | To add | Do this | Scripts must change |
|---|---|---|---|
| X1 | A built-in name | Add one row to the list in Core. It reaches only a script that asks for it (C2). | No |
| X2 | A moment | Add one word to `read`, in one place in Core. | No |
| X3 | A value for a script | Add one environment variable. | No |
| X4 | A Mac feature | Add one `openspot <noun> <verb>`. | No |
| X5 | A part or a value to draw | Add it to the catalog. An old app skips the key (R2). | No |

A change to the meaning of a word that exists is a breaking change. Do not make one without a new word.

## 13. Where the code differs today

The code follows this document.

## 14. Decisions

| Decision | Why | Rejected |
|---|---|---|
| A script lists commands, and the person gives them keys | A key depends on the person's hands and other apps, and a window move through the panel is too slow. The config file holds each key, so a clash has one place, and an update or a shared spot cannot change a key. A header lists the commands, so Settings shows them with no run. | A second global key that arms the letters of spots. A `global` key in the header, which lets a script take a key. |
| One call shape, with only `read` reserved | An author learns one line. A clash can happen only inside one file, and C1 and C2 cover it. | A word for each kind of call. An `action` word. Both add words to learn. |
| Scripts, not a JS runtime | Goal 1. Shell gives each Mac tool at once, and a start costs about 5 ms. | JS only. It loses one-file shell scripts. |
| JS waits | It can come later as one more executable, with `#!/usr/bin/env -S openspot run`, on JavaScriptCore. The contract does not change. It must provide `fetch`, timers and modules. | A JS level now. `node` and `bun` are not on each Mac. |
| Lifetime from rules | A person can see and stop work, so work needs no limit and no key. Nothing wants a stopped sheet, so its read ends. | A `job` key. A `fresh` key. A lifetime value on `stay`. |
| One `SpotSheet` for each script | A metric and a sheet both hold what a script last printed, and a widget can place any script. | A separate table and a separate type for metrics. |
| Hooks are moments of `read` | Each hook need so far is a refresh at a moment, and `stay=true` covers the rest. | A separate `hook` call and a `hooks` key. |
| State behind a capability | A script stays a handler. This removes fifos and a server from each plugin. | A server in each plugin. |
| A capability exits when idle | One rule, the same from a terminal, and the app does not track sheets for it. A language can stay in memory for 30 seconds after the sheet closes. | State that ends with its sheet. It needs a session passed through the app and the script. |
| No `every=` | A number in `read` already means this while something wants the script. A script cannot change its rate while it runs, and nothing needs that. | A second timer. |
| An optional shell helper | Six plugins hold the same escape code, and a handler must read a block from stdin. It adds no call and no key. | A helper as a command, which starts a process for each value. Values in the environment, which share the 1 MB limit. |
| `stay` still exists | A socket or a compiled program has its own state. | Only capabilities. They cannot hold an author's own state. |
| Streaming needs no key | A long call only prints more. | A separate stream mode. |
| A form is the same call | One call shape with no exception. | A `form` word. It is easier in shell, but it adds a word. |
| Header in each file | Goal 1, and a scan runs nothing. | A manifest. It can still come later. |
| No permission model | A script can already do all that the person can. A false limit is worse than none. | A `uses` key. |
| A sheet is a drawing, with one row height | A model writes one form, and each result stays even. | Named layouts. Column ratios, row sizes and nested drawings, which add words that most sheets never need. Sixteen columns, which make long lines and cannot make thirds. |
| Complex views are Swift blocks in the app | The text language stays small, and a plugin still never draws in Openspot (goal 2). Third-party Swift views come in a later phase. | A view in a plugin now. It needs a build, a signing exception and trust in code that no one can read. |
| One progressive backdrop blur close to the cards, and a light dark tint that fades across a 90 pt margin, sampled at full scale, with no constant redraw | One layer gives a soft edge with no line and no second pass, and the long fade of the tint shows no shape, as Control Center does. The system's sampling scale keeps text low-resolution where the mask is zero. | Three masked blur steps, which show a line at the window edge at the system's scale. A system material and Liquid Glass, which do not give this look. |
| A spot travels as a `.spot` file | A chat app takes a file of any size that a script has, and a double-click or a drop adds it. | Encoded text, which hits message limits and hides the code. A link, which needs a hosted page. |
| A `.spot` file is JSON: a format number and files | A standard format that any editor shows. A header already holds each fact about a spot, so the file repeats none. | A zip file, which hides the text. A manifest. |
| A spot travels with what it needs | A widget works only with the metrics it places, and a script in a folder can need the other files of that folder. `$OPENSPOT_DATA` stays behind, because it is private. | Only single scripts, which leaves widgets and folders out. |
| A file of the same name is replaced, and the old one goes to the Trash | The review names each file it replaces. A new name would break the IDs that a widget places. | A new name for each clash. |

**Where the Workers model stops.** A Worker runs in a sandbox, so a binding is both an API and a permission. A script has no
sandbox, so here a binding is only an API (P1). A Durable Object loses its memory when it sleeps. A staying script is a real
process and holds a loaded model, so Openspot does not freeze it. But the same rule holds for the author: memory can go (Y6).

## 15. Open items

**Not decided**

Nothing.

**Not proven**

1. K2: process tests prove one state across separate runs of a script, one helper after a race, and no helper after its idle
   time, with a stand-in capability. By hand on one Mac with English to Russian installed, 8 real calls reached one helper: the
   first took 313 ms and later ones 81 to 114 ms. How much of that gain comes from the kept session, and not from macOS, is not
   proven. `Translate` has not run in the real panel. A helper that hangs and does not crash blocks each call until the person
   stops it.
2. P5: what macOS does when a compiled program under Openspot calls a protected API, such as Calendar. The app can be
   stopped when it has no usage text. Test this before section 8 promises a compiled program any Mac API. The test can show a
   permission prompt, so it needs the person.
3. M3: whether each current plugin still fits the limits when reads run at the same time.
4. L11: whether 1 second is enough to stop a double press from stopping work.
5. D1, D2: a drag over a menu bar item that opens a panel with no change of focus, and the mark that shows from then until the
   drag ends. It needs a real screen and a real drag. An off-screen render proves the mark, and a test proves which cards take
   the files. A drag that reaches an open panel and no card shows no mark until it reaches a card.
6. K2: the start time of the `openspot` command, which each change in `Translate` calls: a median of 9 ms for `catalog` over 20
   calls, and 11 ms for a call through a running helper with no translation, in a Debug build on one Mac. The first run after a
   build took 297 ms. A Release build and a Mac under memory pressure are not measured.
7. Start times: about 5 ms for `sh`, 18 ms for `bun`, 25 ms for `python3`, 60 ms for `node` and 3.4 s for `swift file.swift`.
   One Mac, trivial programs. A later run of a small AppKit script took 1.1 s the first time and 0.37 s after that, and the
   same program took 0.23 s compiled. So a Swift plugin can stay a script.
8. C6: a 1 MB paste reaches the sheet in under 1 second in a Debug build, with the pause of C4. The drawing comes after that, in
   system views. In an off-screen window on one Mac, a Debug build took 1.6 s to draw 1 MB in an editable text part. A read-only
   text part took 4.1 to 4.6 s for 1 MB and drew no text, and it drew text at 500 KB, which took 2.9 s. A Release build and the
   real panel are not measured.
9. Y2: a copy that Openspot ended still runs the calls that it has, for up to 4 seconds (Y4). A call in that time starts a new
   copy, because the old one has no open stdin. So two copies can run for that time.
