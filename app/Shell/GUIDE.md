# Build an Openspot plugin

This guide is for people and for AI agents. It tells you all that you need.

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
A person who gets it as a `.spot` file needs no tools. See "Share a spot".

## The header

Comment lines right under the first line say what a script is, one `key=value` on each line. They can start with `#`,
`//` or `--`. The first other line ends them. Openspot reads them without running the script.

```sh
#!/bin/sh
# name=Morning
# symbol=sun.max
# subtitle=Start the day
# key=m
open -a Calendar
```

| Key | Meaning |
|---|---|
| `name` | The title. The default comes from the file name. |
| `symbol` | An SF Symbol name. |
| `subtitle` | The second line. |
| `key` | One letter. Hold the key that opens the panel, and press this letter to run it. |
| `size` | `wide` (the default), `small`, `square` or `strip`. |
| `order` | Its place in the grid. A lower number comes first, and the default is 0. |
| `grid` | `false` to keep the spot off the grid. Search and its key still find it. With `panel` in its `read`, the first block can print `grid=true` or `grid=false` to change this. |
| `read` | When Openspot reads the script. See below. |
| `rank` | Shows its rows in the main search. A lower number comes first. Needs `panel`, `launch` or a number in its `read`. A number also needs a `key`, or Openspot refuses the plugin. |
| `tray` | `true` to show a metric in the menu bar. Needs a number in its `read`, or `stay=true`. |
| `stay` | `true` to keep the script running. See "Sheets of parts". |
| `drop` | A list of file extensions, `folder` or `*`. Its card takes files that a person drops. See "Drops". |
| `command` | An ID and a title, such as `command=left:Left side`. One line for each command. See "Commands with keys". |
| `data` | The name of a data folder to share with other spots. See "Rules for scripts". |

`read` is a list of moments, split by commas, such as `read=panel,60`. At each moment Openspot calls `<script> read`:

| Moment | Openspot reads it | Use it for |
|---|---|---|
| none | Never. A click runs `<script>` with no argument. | A script that does one thing. |
| `sheet` | When its sheet opens. | A list. |
| `panel` | Each time the panel opens, and once as the app starts. | A toggle, a slider, or a list for the main search. |
| a number | Every that many seconds, while something wants it, such as its open sheet. | A metric. It has no spot unless it also has a `key`. |
| `launch` | When the app starts. | Work to do once, or a staying script that runs at all times. |
| `wake` | When the Mac wakes. | A value that is old after a sleep. |

A read must be safe at each moment that its header lists, so `read` does no work. A script has one read at a time. A
`panel` or a `sheet` moment uses an answer that is younger than 5 seconds. A number, `launch` and `wake` always run. After
a call that prints no state, Openspot reads the script again.

## The calls

| Call | When | The script does |
|---|---|---|
| `<script>` | A click, with no `read` in its header | Does its work. |
| `<script> read [text]` | A moment, a sheet opens, or the search changes with `search=script` | Prints what to show. |
| `<script> run` | A click on a card with no sheet, with a `read` in its header | Does its work. |
| `<script> open <run>` | A row is picked | Opens the row. |
| `<script> <action> [run]` | An action runs | Does it. With `form=true` and empty stdin, it prints the fields. A filled form comes on stdin. |
| `<script> <part> [value]` | A part changes, or a press of a part | Prints the sheet, or nothing to be read again. |
| `<script> on`, `off` | A toggle is pressed | Turns it on or off. |
| `<script> level <number>` | A slider moves | Sets the level. |
| `<script> drop <path> [path]...` | Files are dropped on its card, or chosen for it | Does its work on each file. |
| `<script> <id>` | A key that a person gave a `command` is pressed, in any app | Does its work. |

`read` is the only reserved word. A part or an action cannot be called `read`, and `openspot check` reports it.

A value over 64 KB is left out of the arguments, because the system limits them. Stdin still holds it: a value of the sheet
as it is, and any other value under the key `value`, such as `value=<run>`.

```sh
#!/bin/sh
# name=Notes
# read=sheet
case "$1" in
  read) printf 'row=Today\nrun=today\n' ;;
  open) open -a Notes ;;
esac
```

## What a script prints

A script prints plain text, one `key=value` on each line. A blank line ends a block.

```text
row=Safari
detail=App
run=/Applications/Safari.app

row=Notes
run=/Applications/Notes.app
```

- A line splits at its first `=`, so a value can hold `=`, quotes and spaces.
- A line with no key, a key Openspot does not know and a value it cannot read are skipped.
- An empty value counts as no value.
- A value is one line. In a value, `\n` stands for a new line and `\\` for a backslash. If a value comes from outside your
  script, such as a file name or a web page, write it with `esc` (see "The shell helper").
- For many rows in one pipe, use `sed 's/\\/\\\\/g'`. With `jq -r`, use `def esc: gsub("\\\\"; "\\\\") | gsub("\n"; "\\n");` and write `"row=\(.title | esc)"`.

A block is a row when it has `row`, an action when it has `action`, and a form field when it has `field`. The first other
block says how the spot itself looks, and it can hold `search` and `recents`. Printing nothing means that there is nothing
to show.

To confirm what an action did, print `toast=Saved`. Openspot shows it, also with the panel closed.

## The shell helper

A shell script can load two functions. It is optional. Loading starts `cat` once. Up to 1 KB, each function starts no
program. Above that, it starts `sed`, `tr` or `awk`, and it finishes 1 MB in under 1 second.

```sh
#!/bin/sh
. "$OPENSPOT_SH"
input=$(value input)
printf 'part=output\ntext=%s\n' "$(esc "$input")"
```

- `esc <text>` writes text as a value: a backslash as `\\` and a new line as `\n`.
- `value <id>` prints the real text of one value from stdin. It prints nothing when stdin has no such value.
- Loading the file reads all of stdin once, so read stdin only through `value` after that.
- `$(...)` drops the new lines at the end of a value. To keep them, write `text=$(value id; printf x)` and use `${text%x}`.
- A script with `stay=true` keeps its stdin for its calls. There, `esc` works, and `value` prints nothing.

## Lists

A script that prints rows is a list. Each row is one block:

```text
row=Safari
detail=App
run=/Applications/Safari.app
file=/Applications/Safari.app
```

`row` and `run` are the only keys a list needs. Also use `symbol` for an SF Symbol, `file` for a file's icon, `image`
for a path to an image, or `glyph` for a short text, such as an emoji. `hides` is the ID of an action that this row does not offer. Repeat the line for each one.
`shortcut=ctrl+space` shows a key at the end of the row. A pick records the next key, and Openspot calls `<run> <key>`.

Openspot searches the rows itself and sorts recent picks first. To change this, print one block before the rows on each
read:

| Prints | Does |
|---|---|
| `search=script` | Each search change calls `<script> read <text>`. The script prints the rows that match. |
| `recents=false` | Does not sort recent picks first. |

To show rows as square buttons, print `repeat=<letter> <per line>` in that block. Each button draws its picture, and the
title of the selected button shows in the sheet's header. To add parts around the rows, draw them. The repeated area scrolls,
and the app draws the search field over the sheet:

```text
grid=t t t t t t t
grid=a a a a a a a
repeat=a 7

part=tone
cell=t
title=Skin tone
option=none:Yellow
option=medium:Medium
value=none

row=thumbs up
run=👍
glyph=👍
```

## Toggles and sliders

Give the script `read=panel`, and let it print one block:

| Prints | Shows |
|---|---|
| `on=true` or `on=false` | A toggle. |
| `level=70`, and `min=0` and `max=100` | A slider. |

Both can print `title` and `detail`. The defaults come from the header.

## Drops

Add `drop` to the header, and the card takes files.

```sh
#!/bin/sh
# name=To MP4
# symbol=film
# drop=mov,mkv,avi,webm
case "$1" in
  drop)
    shift
    for file; do
      ffmpeg -y -i "$file" "${file%.*}.mp4" >/dev/null 2>&1 || exit 1
    done
    printf 'toast=Done\n'
    ;;
esac
```

| `drop` holds | The card takes |
|---|---|
| An extension, such as `mov` | A file with this extension, in upper or lower case. |
| `folder` | A folder. A bundle, such as an app, is a folder. |
| `*` | Each file and each folder. |

- To drop files, drag them over the Openspot item in the menu bar. The panel opens and the focus stays where it is. The panel stays open until the drag ends.
- A card takes a drag only when its `drop` takes each dragged file. For the whole drag, each such card changes its fill, and the card under the drag fills fully, because it takes the drop. Other cards do not change. A mix with one other file goes to no card.
- A drop runs one call, `drop <path> [path]...`, and closes the panel. Each full path is its own argument, so write `"$file"` with its quotes.
- A drop on a card with a running call waits, and runs when that call ends. It does not stop the call. A `read` does not hold a drop.
- A click on a card with `drop` and no sheet opens a file chooser, and the choice runs the same call. A toggle and a slider keep their own click, and a card with a sheet opens its sheet.
- A `drop` call runs as any other name does. It has no time limit, and it goes on with the panel closed. A second press of its card stops it.

## Commands with keys

A script lists what it can do, and the person chooses the keys. A script never holds a key.

```sh
#!/bin/sh
# name=Music
# command=pause:Play or pause
case "$1" in
  pause) osascript -e 'tell application "Music" to playpause' ;;
esac
```

Settings shows one row for each command, and the person records a key there. A press in any app runs `<script> <id>` with no panel, and the script can print `toast=Done`. The file `config.toml` holds each key, and a person can also write it by hand:

```text
[[keys]]
spot = "music"
command = "pause"
key = "ctrl+option+p"
```

- A key holds cmd, ctrl or option, with a letter, a digit, an arrow, space, return or tab.
- Presses run one at a time and in order. A press never stops a call, so keep the call short.
- A key that macOS refuses shows a toast. A hand edit takes effect when the panel next opens.
- A key works with the panel open too, so the front app can be Openspot.

## Actions and forms

An action is an extra thing to do. It shows in the ⌘K menu, and its key works directly. A list prints its actions with
its rows:

```text
action=copy
title=Copy
key=cmd+return
close=true
```

| Key | Meaning |
|---|---|
| `action`, `title` | Required. The call is `<script> <action> <run>`. |
| `key` | Such as `cmd+e`, `cmd+return` or `cmd+shift+d`. |
| `scope` | `command` for an action that needs no selected row. |
| `close` | `true` to close the panel after it runs. |
| `confirm` | Words that ask for a second press, such as `Press again to delete`. |
| `form` | `true` to ask for values first. |

`action=open` is special, because it sets what Enter does on a row. `title` is the word for Enter, and the default is
`Open`. `close=false` keeps the panel open after a pick.

An action with a form first runs as `<script> <action> [run]` with empty stdin. It prints a block with the title, then one
block for each field:

```text
title=New note

field=text
label=Text
type=multiline
required=true
```

A field needs `field`, its name, and `label`. `type` is `text` (the default) or `multiline`. `value` and `placeholder`
are optional. After the person fills the form, the same call runs with the values on stdin as one block, such as
`text=one\ntwo`, and it can print the `run` value of the row to select.

## Sheets of parts

A script that prints parts opens a sheet of them, with no search field. Run `openspot catalog` for the whole language,
with examples. A model can write a good sheet from that text alone.

A sheet is a drawing and parts. Draw it with one letter for each area, and a part takes a letter with `cell`. The words of a
line set the columns, so a wider area takes more words. A smaller area on a larger one floats, with its own background:

```text
grid=t t t t
grid=t t t c

part=note
cell=t
text=Buy milk

part=save
cell=c
look=strong
press=checkmark
```

Each row has one height, so a taller area takes more lines. Rows that hold text, a list, a chart or a picture share the free
height. A letter with no part stays empty.

With no drawing, a sheet is one column of lines, and `section=<id>` starts a new group with a divider.

The app owns each gap, row height and centre. A script says only which part goes where, and cannot make an uneven sheet.

| Prints | Shows | Openspot calls |
|---|---|---|
| `title`, `detail`, `symbol` | A line, with a value on the right. | |
| `on=true` | A switch. | `<id> true` or `false` |
| `level=70`, `min`, `max` | A slider. | `<id> <number>` |
| `color=#ff0000` for each swatch, `value` | A row of colours. | `<id> <color>` |
| `option=en:English` for each choice, `value` | A menu. | `<id> <option id>` |
| `item=a:Address` for each row, `value` | A list to choose from. | `<id> <item id>` |
| `shortcut=ctrl+space`, with `title` | A key that a click records. | `<id> <key>` |
| `text=...`, `placeholder` | A text area. `readonly=true` only shows the text. | `<id> <text>` |
| `press=arrow.clockwise` | A round button. | `<id>` |
| `press=true` | A button that fills its cell. | `<id>` |
| `metric=42%`, `point=3`, `image=<path>`, `block=progress` | A number, a chart, a picture, a progress bar. | |
| `keys=7 8 9 +` in the layout block | A row of key buttons. | `<word>` |

The script holds no state. Each call gets all values on stdin, as one block such as `input=one\ntwo`. It prints the
whole sheet again, or prints nothing to be read again. It can also print `toast=Saved`. To read an open sheet again every 5
seconds, put a number in its header: `read=5`.

Openspot shows a change at once, and only the answer to the newest change shows. It waits for a pause in typing and in
a slider's motion. Text that the person is typing stays as typed until they press something.

A call can keep printing, as `ffmpeg` does. A line `---` ends a frame, and the app draws it at once. A frame with a layout
replaces the sheet, and a frame with only parts changes those parts.

Two rules decide how long a call runs:

- A `read` has 10 seconds until its first frame or its end. It stops when nothing wants it, so a stream from a `read` stops
  when its sheet closes.
- Any other name has no time limit. It keeps running with the sheet and the panel closed, and Openspot keeps its last frame
  for the sheet. With no open sheet, a frame shows only its `toast`, its `on` and its `level`.

These stop a call:

- A new value for a part stops the older call of that part.
- A second press of a running part, action or card stops its call. Each process in its group gets the terminate signal.
  After 2 seconds, Openspot kills what still runs. A press within 1 second of the start of the call does nothing, so a
  double press does not stop it.
- Quitting Openspot stops each call. To outlive the app, start the work with `nohup` and then exit. A stop reaches the whole
  group, so `nohup` does not protect a child while its script still runs.

A stopped call changes nothing. A call ends when its output closes, so a script that leaves a child running sends the
output of that child somewhere else. A failed call always tells the person. A failed `read` from a number only dims the
last value.

A call that does work reports its progress with the values that a metric prints:

```text
title=42%
value=0.42
detail=2 min left

---
```

After the call has run for 1 second, its spot shows a ring from `value`, and a spinner with no `value`. Only the last frame
counts. The `title` and the `detail` show on the spot only while the call runs. The Openspot item in the menu bar shows the
oldest call and how many run, and a click on it opens the panel with that spot selected. The part or the action of the call
shows that it runs, and says that a press stops it.

Closing the panel closes a sheet of parts and drops its values, and the next open reads again. A sheet of rows stays open.

A script with `# stay=true` in its header runs while something wants it, so that a model or a connection stays loaded
between calls. Something wants it while its sheet is open and the panel is open, while the panel is open and a widget
places it or `panel` is in its `read`, while the menu bar shows it, or at all times with `launch` in its `read`. It starts
when something first wants it, and the sheet shows with its first frame. When nothing wants it, Openspot closes its input.
After 2 seconds its group gets the terminate signal, and 2 seconds after that Openspot kills what still runs.

It gets one block on stdin for each call, with a blank line after it: `name`, `value`, and one `field.<id>` for each value
of the sheet. A `drop` has one `value` line for each path. A pick, an action, a form and a drop reach the script that runs,
and no call starts a second copy. It keeps its own state, and answers with frames. Openspot cannot see where such a call
ends, so it shows no running mark and a press does not stop it. Say what the script does in its own frames.

If it ends and something still wants it, the next moment or call starts it again. After 3 failures in one minute, Openspot
tells the person, and does not start it again until a scan finds its file changed.

To read the sheet when the panel opens, so that it opens at its full size, use `read=panel`. Otherwise use `read=sheet`.

To try a sheet, run `openspot sandbox`, or `openspot sandbox <file>` to watch a file or run a script. It shows the real
sheet and its faults at once. `openspot check --sheet` reports the faults of a sheet on stdin, and `openspot render
<file.png>` draws it to a picture.

## The openspot command

A script finds `openspot` on its path. It gives what macOS has no command for, in plain text.

| Call | Does |
|---|---|
| `openspot check [folder]` | Reports the faults of a plugins folder. |
| `openspot check --sheet` | Reports the faults of a sheet on stdin. |
| `openspot catalog` | Prints the whole sheet language, with examples. |
| `openspot render <file.png>` | Draws the sheet on stdin to a picture. |
| `openspot sandbox [file]` | Opens a window to try a sheet from text, a file or a script. |
| `openspot color pick` | Prints the colour the person picks. Prints nothing on a cancel. |
| `openspot translate [--from code] [--to code]` | Translates the text on stdin on this Mac. Prints `text` and `from`, or `status=missing`, `unsupported`, `unknown` or `failed`. |
| `openspot translate languages` | Prints each language, with its name. |
| `openspot emoji [--tone name]` | Prints each emoji as a row, with its name in the language of the Mac. A tone is `none`, `light`, `medium-light`, `medium`, `medium-dark` or `dark`. |

When macOS already has a command, use it: `pbcopy`, `open`, `say`, `caffeinate`, `mdfind`, `screencapture`,
`shortcuts run`, `osascript`.

A capability works the same from a script and from a terminal. It can stay loaded between calls: `openspot translate`
keeps each pair of languages in memory, and they leave memory 30 seconds after the last call. Your script does nothing for
this. It never starts, finds or stops anything, and it stays a handler that runs once for each call, as `translate.sh` does.
When a call cannot start what it needs, it exits with code 1 and one line on stderr that says the cause and the fix.

To use `openspot` in a terminal, turn on Use openspot in Terminal in Settings. It links `/usr/local/bin/openspot` to the
command inside the app, and macOS asks for your password when that folder needs it.

## Metrics

A metric is one piece of live data. Any widget can show the value of any script with a `read`, by its ID, which is its path with no extension, such as `coffee` or `home/coffee`. A script with a number in its `read` keeps the value fresh, and it has no spot unless it also has a `key`.

File `coffee.sh`:

```sh
#!/bin/sh
# name=Cups today
# symbol=cup.and.saucer.fill
# read=60
printf 'title=3\ndetail=Last at 14:20\n'
```

Openspot reads a metric only when a widget places it and the panel is open, or when the menu bar shows it.
When a read fails, the last value stays and dims.

`name` says what the metric measures, and each place shows it. Do not repeat it in the values. `symbol` can also be
printed, when it changes.

Marks are white. A `tone` colours a mark to say what it means: `good`, `warn` or `bad`. Use it only when the colour means
something. `tint` also colours the mark, and it is optional: use red, orange, yellow, green, mint, teal, cyan, blue,
indigo, purple or pink, and only when the colour helps a person find one metric among many. Text stays white.

What a metric prints decides how it shows:

| Prints | Shows |
|---|---|
| `title` | A number or a word. |
| `title` and `value=0.84`, from 0 to 1 | A ring. |
| `title` and one `point=2` line for each bar | Bars from zero. The last bar is the newest. `max=100` sets a fixed top value. |
| `title` and `tone`, with no `symbol` | A dot with a word. |
| A block with `row=Build` for each row | Short lines, as many as fit. Each can have `detail=2m` and `tone=good`. `title` is the count unless you print one. |

## Widgets

A widget is a spot that shows metrics in a layout. It runs nothing, and it can place metrics of any plugin. Widgets live
in a `.toml` file in the plugins folder:

```toml
[[widgets]]
name = "Morning"
layout = "hero"
places = ["agents", "battery", "cpu", "disk"]
opens = "links"
```

`places` fills the cells of the layout in order, and each cell needs one metric. `opens` is optional: it names the
command that Enter or a click runs. `key` also works. Its sheet grows out of the widget. Give that
command `grid=false`, so that it has no card of its own.

A widget can also draw its own layout, in the same letters as a sheet's `grid`. Each letter is a rectangle, `.` is empty,
and `places` names a metric for each letter:

```toml
[[widgets]]
name = "Desk"
grid = ["a a b b", "a a c c", "a a d d"]
places = { a = "agents", b = "battery", c = "cpu", d = "disk" }
```

A one-line drawing is a `strip` and any other is `large`, unless `size` asks for another. The app sets the gaps, and each
place takes its form from the room its cell has: a cell with two columns and two rows shows the large form, a shorter one
a line, and one column of the card only the value.

| Layout | Size | Places |
|---|---|---|
| `single` | 2x2 | One metric. Use `size` to ask for `small` (1x1) or `wide` (2x1). |
| `hero` | 4x2 | One large on the left, three lines on the right. |
| `pair` | 4x1 | Two, each with its mark at the outer edge. |
| `row` | 4x1 | Four values, each over its label. |

A size is a preference. The grid fills each row: four small spots stay 1x1, and fewer than four grow. The same is true
for a command with `size=small`, which shows only its symbol.

A large place shows the detail. In a `hero` line, a trend with `max` shows as one bar. Other places show only the label,
the value and the mark, so keep the title short, such as `84%`.

## The menu bar

Add `tray=true` to the header of a metric to show it in the menu bar. It needs no widget. Openspot then reads it all the
time, so choose a `read` that is not too short.

A click opens the panel on the metric's list if it also has a `key`. If not, the panel opens and selects a widget that
places it.

The item shows the metric's `symbol` and its mark. Rows show one count for each `tone`, worst first. A ring, bars and a
dot show small, and a `title` shows as text.

Print nothing to remove the item until the next read, such as when nothing is running. Widgets in the panel still show
the metric.

## Share a spot

To send a spot to another person:

1. Select the spot and press ⌘K.
2. Choose "Copy to share", or press ⌘⇧C. This puts a `.spot` file on the clipboard.
3. Paste the file into a chat or a mail. Check it for secrets first, because Openspot does not.

To install a spot that you got, double-click its `.spot` file, drop it on the Openspot item in the menu bar or on the panel, or
copy the file and press ⌘V in the panel. The path of the file in the search field also works. The panel says what the file is before you drop it.
Openspot shows what runs by itself, each file that it replaces and all the text it can. It names each file that it cannot show,
and a program comes first. Nothing runs until you press ⌘⏎ to add it.

A `.spot` file is JSON. It holds a format number and the files:

```json
{
  "files": [
    { "executable": true, "path": "weather.sh", "text": "#!/bin/sh\nsay hello\n" }
  ],
  "format": 1
}
```

- A script in a folder takes the whole folder. A widget takes each script that it places or opens.
- A file that is not text uses `data`, in base64, in place of `text`.
- Hidden files and `$OPENSPOT_DATA` stay behind.
- A compiled program travels, but no one can read it first. Install one only if you trust the sender.
- "Copy to share" compiles a Swift script for both kinds of Mac, and adds `<name>.program` beside it. The sender needs the Command Line Tools, and the receiver needs nothing. The source gives the header, the program runs in its place, and a program file is never a spot of its own. To run an edited source, delete the program.
- A file with the same path is replaced, and the old file goes to the Trash.

## Delete a spot

Select the spot and press ⌘⌫ twice, or press ⌘K and choose "Delete". Its file goes to the Trash. The other files of its folder and
what it keeps in `$OPENSPOT_DATA` stay. A widget file goes whole, with each widget in it.

## Check your work

Run this before you stop. It loads each plugin and reads each one that has a `read`. It prints each fault, and it exits
with 1 when there is a fault. It does not run a script with no `read`.

```text
openspot check <plugins folder>
```

## Rules for scripts

- Print only the data. Send each message for the person to stderr. When a script fails, its last stderr line shows.
- Exit with 0 on success. Any other code is a failure.
- Be fast in `read`. It has 10 seconds until its first frame or its end. Reads run at the same time, so a slow script delays no other. Any other name has no limit.
- Keep files in `$OPENSPOT_DATA`, not in the plugin folder. Openspot creates this folder for each spot. Scripts in one plugin
  folder share it. To share it with other spots, give each one the same `data=<name>` in its header.
- Write a file to a temp name, then move it: `... > "$file.$$" && mv "$file.$$" "$file"`. A stop can come at any time, and two
  calls of one script can run at the same time, so a file must never be half written.
- Use short plain words in sentence case. Start an action's name with a verb.
- Do not use a `key` that another plugin has. The first plugin keeps it.
- A plugin runs with the full access of the person. If you are an agent, tell the person what yours runs.
