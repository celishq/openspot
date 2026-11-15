# Openspot guide

Openspot runs small programs called spots. You write a spot in any language. It prints a few lines that say what to
show, and Openspot draws them. When something happens, such as the user opening the spot, Openspot runs it again.

This guide shows how to write one, a task at a time. The [protocol](PROTOCOL.md) gives every rule.

## How it works

Press the Openspot hotkey, and the **panel** opens. It has a search field, and a grid of **cards** under it. Each card is
a spot. Press a card, and its **sheet** opens: a bigger view of that spot, with its text, its controls and its list.

A spot is a script in a spot folder, such as `cups.spot/cups.sh` in the spots folder. Openspot runs it when something
happens, the spot prints what to show, and Openspot draws it. When the user presses something, Openspot runs the spot
again with the id of what was pressed. The [protocol](PROTOCOL.md) gives every rule of that loop.

## Your first spot

The smallest spot is a script. Press its card, and it runs.

```sh
#!/bin/sh
say hello
```

Comment lines at the top give it a name and an icon. These lines are the **header**.

```sh
#!/bin/sh
# title=Morning
# icon=sun.max
open -a Calendar
```

To show something, add an `on=` line. It tells Openspot when to ask the spot what to show. Here, Openspot asks when the
sheet opens, and the spot prints a title and a detail.

```sh
#!/bin/sh
# title=Cups today
# icon=cup.and.saucer.fill
# on=sheet.open
printf 'text=cups\ntitle=3\ndetail=Last at 14:20\n'
```

![The sheet of Cups today: one line, 3, with Last at 14:20 at its end](docs/images/first-spot.png)

Each group of lines that the spot prints is a **block**: here, one `text` block with the id `cups`. The sheet shows **3**,
with **Last at 14:20** at the end of the line.

## Try your spot

Try each example of this page in the playground before you put it in the spots folder.

- **Playground.** Open the Playground spot, or run `openspot playground [file]`. Type a spot, or pick one from Examples.
  It runs in a panel of its own: pick its sheet or its card, and type in the panel's search to try its answers. Under
  it, you see each call with its arguments, its stdin, what it printed, its stderr and how it ended. When you open a
  file, edits go straight to the file.
- **New spot.** `openspot spot new <name> --from <kind>` writes a working spot that you can change. The kinds are
  `button`, `list`, `number` and `form`.
- **One call.** `openspot spot run <id> [call] [value]...` runs one call the way Openspot does, and prints everything the
  spot prints. With no call, it asks the spot what to show. While Openspot is open, the script gets the variables of
  the app, not those of your shell.
- **Image.** `openspot render [--view <file>] <file.png>` draws the sheet that stdin holds. `--card <size>` draws its card,
  and `--spot <id>` draws an installed spot.
- **Log.** `openspot spot log <id>` prints the last calls to a spot, with their stdin, stdout, stderr and exit code.
- **Check.** `openspot check [--json] <folder>` loads each spot, runs it once, and prints each error. Run it before you
  share a spot.

## Show a list

A list lets the user search and pick. Print one `row` block for each item. When the user picks a row, Openspot runs your
spot with `open` and the id of the row.

```sh
#!/bin/sh
# title=Apps
# icon=square.grid.2x2
# on=sheet.open
. "$OPENSPOT_SH"
case "$1" in
  read) printf 'Mail\tMail\tYour inbox\tenvelope\nNotes\tNotes\tYour notes\tnote.text\n' | openspot_rows ;;
  open) open -a "$2" ;;
esac
```

![The sheet of Apps: two rows, Mail and Notes](docs/images/show-a-list.png)

The sheet shows two rows, **Mail** and **Notes**. Type in the sheet's search field, and Openspot filters the rows for
you. Pick **Notes**, and Openspot runs `apps.sh open Notes`.

The first argument tells your spot what to do. `read` asks what to show. Any other word is something the user did. The
shell helper, `$OPENSPOT_SH`, prints rows for you and escapes each value.

Learn more in [Rows](PROTOCOL.md#rows) and [The calls](PROTOCOL.md#the-calls).

## Open a row as a page

A page shows the detail of a row as a sheet of its own, and keeps the list it came from. Name the pages in the header
with `pages=`, give the row `push=true`, and print the page when `OPENSPOT_PAGE` holds its id.

```sh
#!/bin/sh
# title=Fruit
# icon=leaf
# on=sheet.open
# pages=*
. "$OPENSPOT_SH"
case "$OPENSPOT_PAGE" in
  '') printf 'row=apple\ntitle=Apple\npush=true\n\nrow=pear\ntitle=Pear\npush=true\n' ;;
  *) openspot_row "$OPENSPOT_PAGE:color" "Color" "Green" ;;
esac
```

Pick **Apple**, and its page opens in place of the list, with one row, **Color**. Press `⌘[` to go back to the list,
and `⌘]` to go forward to the page again. Esc takes the page off, so `⌘]` has nothing to go to. `⌘Esc` goes back to the grid.

Each call of a page gets its id in `OPENSPOT_PAGE`, so a press on the page knows which page it came from. A press can
move the flow too: print `pop=true` after it saves, and the list shows again. A row or a press with `push.spot=` pushes
another spot, which reads what to show from its page, as a web page reads its URL.

Learn more in [Pages](PROTOCOL.md#pages).

## Show a value on a card

A card can show one live value, such as free disk space. `on=panel.open` asks your spot each time the panel opens, and
`on=clock.300` asks it again every 5 minutes while the card shows.

```sh
#!/bin/sh
# title=Disk
# icon=internaldrive
# on=panel.open
# on=clock.300
# offers=card
# offers=menubar
free=$(df -h / | awk 'NR==2 {print $4}')
printf 'detail=%s free\n\ntext=free\ntitle=%s free\n' "$free" "$free"
```

<!-- card: wide -->
<!-- draw: df() { printf 'Filesystem Size Used Avail\n/dev/disk 994Gi 738Gi 256Gi\n'; }; . "$EXAMPLE" -->
![The card of Disk, with the free space under its title](docs/images/show-a-value.png)

The first block, `detail=…`, is the **head**: it isn't drawn, and its `detail` becomes the line under the card's title.
The `text` block is the spot's **main block**. `offers=card` and `offers=menubar` name the places where the spot can show
it: a card on the grid, and the menu bar, next to the clock. The user puts the spot in the menu bar from its Settings,
which `⌘⏎` on its card opens.

A spot with a clock stays off the grid until the user adds it, so that a new spot doesn't fill the panel.

Learn more in [The main block and the card](PROTOCOL.md#the-main-block-and-the-card) and [Events](PROTOCOL.md#events).

## Add buttons

A button runs a command. Give each button an id. When the user presses it, Openspot runs your spot with that id.

Buttons in the header turn the spot into a set of commands, with no card. The user finds each command in the main
search, and gives it a hotkey in the spot's Settings.

```sh
#!/bin/sh
# title=Windows
# icon=macwindow
# uses=screen
#
# button=full
# title=Full screen
# icon=rectangle.inset.filled
#
# button=left
# title=Left side
# icon=rectangle.lefthalf.inset.filled
case "$1" in
  full) openspot window move "0 0 1 1" ;;
  left) openspot window move "0 0 1/2 1" ;;
esac
```

Add `confirm=` to a header button whose command can't be undone. The first press shows its words, and the second runs
the command. Its hotkey asks the same way.

```sh
#!/bin/sh
# title=Notes
# icon=note.text
#
# button=clear
# title=Clear my notes
# confirm=Press again to clear your notes
case "$1" in
  clear) rm -f "$OPENSPOT_DATA/notes" && echo 'toast=Cleared' ;;
esac
```

A button that the spot prints acts on its rows. If no layout places it, it shows in the ⌘K menu of the sheet, and its
shortcut works while a row is selected.

```sh
#!/bin/sh
# title=Notes list
# on=sheet.open
. "$OPENSPOT_SH"
case "$1" in
  read)
    openspot_row today Today
    printf '\nbutton=trash\ntitle=Move to Trash\nshortcut=cmd+backspace\nconfirm=Press again to delete\n'
    ;;
  trash) rm -f "$OPENSPOT_DATA/$2" ;;
esac
```

![The sheet of Notes list: one row, Today](docs/images/add-buttons.png)

Select **Today** and press ⌘⌫ twice, and Openspot runs `notes-list.sh trash today`.

A row can hold keys of its own, such as `path=`. An action on that row gets each of its keys on stdin, so the spot
doesn't look the row up again.

```sh
#!/bin/sh
# title=Downloads
# on=sheet.open
. "$OPENSPOT_SH"
case "$1" in
  read)
    openspot_row report Report.pdf
    openspot_kv path "$HOME/Downloads/Report.pdf"
    printf '\nbutton=reveal\ntitle=Show in Finder\nshortcut=cmd+o\n'
    ;;
  reveal) open -R "$(value path)" ;;
esac
```

Select **Report.pdf** and press ⌘O, and `value path` prints the path that the row holds.

Learn more in [Buttons and actions](PROTOCOL.md#buttons-and-actions).

## Ask for values

A button with `form=true` asks the user for values before it runs. Openspot runs it once with empty stdin to get the
form, then again with the values the user typed.

```sh
#!/bin/sh
# title=Quick note
# on=sheet.open
. "$OPENSPOT_SH"
case "$1" in
  read) printf 'text=hint\ntitle=Press ⌘K to add a note\n\nbutton=add\ntitle=Add note\nform=true\nscope=spot\n' ;;
  add)
    note=$(value note)
    if [ -z "$note" ]; then
      printf 'title=New note\n\nfield=note\ntitle=Note\n'
    else
      printf '%s\n' "$note" >> "$OPENSPOT_DATA/notes"
      openspot_kv toast "Saved"
    fi
    ;;
esac
```

Choose **Add note**, and a form with one field opens. Type a note and press Return. The spot saves it, and a toast says
**Saved**. `value note` reads the field from stdin.

Learn more in [Buttons and actions](PROTOCOL.md#buttons-and-actions) and [The head](PROTOCOL.md#the-head).

## Answer the main search

A spot can answer what the user types in the main search, like a calculator. Add `on=search.text` with a pattern. When
the text matches, Openspot asks your spot right away and shows its answer first.

```js
// title=Calculator
// icon=equal.square
// on=search.text ^[0-9(]
// uses=clipboard
function main(args, env) {
  if (args[0] === "read")
    return openspot.call(["calc", "solve", env.OPENSPOT_VALUE]).stdout;
  return "";
}
```

<!-- draw: openspot calc solve 2+2 -->
![The answer to 2+2: one row, 4](docs/images/answer-the-search.png)

Type `2+2`, and the answer shows at the top of the main search. `OPENSPOT_VALUE` holds the typed text. A `.js` file runs
inside Openspot, so it answers in the same keystroke.

Learn more in [Places](PROTOCOL.md#places) and [Modes](PROTOCOL.md#modes).

## Respond to the Mac

Events let a spot update when something happens on the Mac, such as another app coming to the front. A filter after the
event narrows it down.

```sh
#!/bin/sh
# title=Notes
# on=sheet.open
# on=app.front com\.apple\.Notes
printf 'text=n\ntitle=%s\n' "$OPENSPOT_REASON"
```

<!-- draw: OPENSPOT_REASON=app.front sh "$EXAMPLE" -->
![The sheet of Notes after Notes came to the front: one line, app.front](docs/images/respond-to-the-mac.png)

Bring Notes to the front while the sheet shows, and Openspot asks the spot again. `OPENSPOT_REASON` says why:
`sheet.open` or `app.front`.

Some events bring a value. `system.load` comes every 5 seconds while the sheet shows, with the load of the Mac in
`OPENSPOT_VALUE`, so the spot starts no tool to measure it.

```sh
#!/bin/sh
# title=Load
# icon=gauge.with.needle
# on=sheet.open
# on=system.load
case "${OPENSPOT_VALUE-}" in
  cpu=*)
    cpu=${OPENSPOT_VALUE#cpu=}
    printf 'text=cpu\ntitle=%s%% CPU\n' "${cpu%% *}"
    ;;
  *) printf 'text=cpu\ntitle=Measuring…\n' ;;
esac
```

<!-- draw: OPENSPOT_VALUE='cpu=12 memory=61' sh "$EXAMPLE" -->
![The sheet of Load: one line, 12% CPU](docs/images/show-the-load.png)

The sheet opens with **Measuring…**, and shows the first value within 5 seconds.
`power.change`, `disk.mount` and `device.connect` tell a spot of a new power source, a disk and a USB device the same
way.

Learn more in [Events](PROTOCOL.md#events).

## Combine spots on one card

One card can show several spots side by side, such as the battery, the CPU and the memory. You write only a header, and
Openspot fills the card with the main blocks of the spots that it names.

```sh
#!/bin/sh
# title=System
# grid.large=battery battery cpu    cpu
# grid.large=battery battery memory memory
# to=system-info
```

<!-- card: large -->
![The System card: the battery on the left, the CPU over the memory on the right](docs/images/combine-spots.png)

Each word is the id of another spot. At the large size, the card shows the battery on the left, and the CPU over the
memory on the right. Press the card, and the spot `system-info` opens.

Learn more in [Cards of other spots](PROTOCOL.md#cards-of-other-spots).

## Let the user choose a setting

A setting keeps a choice of the user, such as a folder. Name it in the header with a `field` block, and the spot's
Settings list it. The user opens them with `⌘⏎` on the spot's card, or with **Settings** in its ⌘K menu.

```sh
#!/bin/sh
# title=Repos
# on=sheet.open
#
# field=folder
case "$1" in
  read) printf 'text=folder\ntitle=%s\n' "${OPENSPOT_SETTING_FOLDER:-Choose a folder in Settings}" ;;
  folder)
    picked=$(openspot folder pick)
    [ -n "$picked" ] && openspot setting set folder "$picked"
    ;;
esac
```

<!-- draw: OPENSPOT_SETTING_FOLDER=/Users/me/Code sh "$EXAMPLE" read -->
![The sheet of Repos: one line, /Users/me/Code](docs/images/read-a-setting.png)

In the Settings of Repos, choose **Folder**, and Openspot runs `repos.sh folder`. The spot asks for a folder and keeps it.
Each later call gets it in `OPENSPOT_SETTING_FOLDER`, so the spot reads its setting with no `openspot` call.

A field with `type=secret` keeps a value that no other program should see, such as the token of a service. Openspot
asks for it in a form of its own, keeps it in the Keychain, and gives it to each call only on stdin, as
`setting.token`. A secret has 8 characters or more.

```sh
#!/bin/sh
# title=Weather
# on=sheet.open
#
# field=token
# type=secret
. "$OPENSPOT_SH"
if [ -n "$(value setting.token)" ]; then
  printf 'text=state\ntitle=Signed in\n'
else
  printf 'text=state\ntitle=Set a token in Settings\n'
fi
```

Learn more in [Settings](PROTOCOL.md#settings).

## Write a spot in Swift

A spot can be a Swift program, for work that a shell script does badly. Openspot builds it once, and runs the built
program at each call. Each `source=` line names one more Swift file, or a folder of them, to build with it.

```swift
#!/usr/bin/env swift
// title=Cups today
// icon=cup.and.saucer.fill
// on=sheet.open
// source=cups.swift
print("text=cups\ntitle=\(cups) cups")
```

```swift
let cups = 3
```

![The sheet of Cups today: one line, 3 cups](docs/images/swift-spot.png)

The first file is the spot: its header is in `//` lines, and its code runs first. `cups.swift` sits next to it. The
first call waits for the build, which needs the Command Line Tools. A spot that you share carries its built program, so
the Mac that gets it needs no tools.

Learn more in [A Swift spot](PROTOCOL.md#a-swift-spot).

## Draw your own view

A view draws what blocks can't. Name a SwiftUI file with `view=` in the header, and print a `view` block where it
draws. The view reads the keys of its block, and the rows of the frame.

```sh
#!/bin/sh
# title=Cups this week
# icon=chart.bar
# on=sheet.open
# view=week.swift
printf 'view=week\n\n'
printf 'row=mon\ntitle=Monday\ncups=3\n\n'
printf 'row=tue\ntitle=Tuesday\ncups=1\n\n'
printf 'row=wed\ntitle=Wednesday\ncups=2\n'
```

```swift
import SwiftUI

struct SpotView: View {
    let spot: SpotInput

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            ForEach(spot.rows) { row in
                RoundedRectangle(cornerRadius: 4)
                    .fill(spot.accent)
                    .frame(width: 28, height: 16 * CGFloat(Int(row["cups"] ?? "") ?? 0))
            }
            Spacer()
            Image(systemName: "cup.and.saucer.fill")
                .symbolEffect(.pulse, isActive: spot.isShown)
            Button("Done") { spot.close() }
        }
        .padding(spot.inset)
    }
}
```

![The sheet of Cups this week: three bars, a cup and a Done button over the rows Monday, Tuesday and Wednesday](docs/images/own-view.png)

`spot.rows` holds each row with its keys, so the bars need no second copy of the data. In a sheet, Openspot draws the
rows under the view. `spot.isShown` is false while the panel is hidden: stop a motion or a timer then, as the cup stops
its pulse. `spot.close()` closes the sheet, as Esc does.

Learn more in [Views](PROTOCOL.md#views).
