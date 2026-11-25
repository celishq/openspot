# Use Openspot

This page is for the person who uses Openspot: the keys of every spot, where a spot shows, and the look of the app.

## Use the keys of a spot

Every spot answers the same keys, so you learn them once.

| Key        | Does                                                                          |
| ---------- | ----------------------------------------------------------------------------- |
| Return     | Runs the spot's one action with a title, or opens its sheet.                  |
| `⌘` Return | Opens the spot's Settings: its keys, each setting and its places.             |
| `⌘Y`       | Opens the History of a spot whose Return runs its action.                     |
| `⌘K`       | Opens the menu of all actions.                                                |

- A press of a card, its key, a click in the menu bar and its slash command do what Return does.
- The ⌘K menu of a card starts with what you do with the spot, then Settings, Edit and Change Icon, then Remove.
- Remove, or `⌘⌫`, moves the spot's folder to the Trash. Its data and its settings stay, so the spot has them again when
  you install it again.
- An install of a spot whose id your spots have already asks, as Finder does: Replace moves yours to the Trash, Keep
  Both installs the new one under a new id, such as `ports-2`, and Stop leaves both as they are.
- A spot you installed updates from its store while you leave its files as they came. The Store shows the day of its
  version, such as "Updated 3 Nov". An update that asks for a new use waits for your yes, and names only what it adds.
  Once you edit the spot, it takes no update: the Store says "Edited, updates paused", and `openspot store revert`
  moves your copy to the Trash and puts the store's version back. Its data stays.
- Edit copies a prompt that sends an agent to the spot's file. You change a spot there, not in its Settings.
- A spot that comes with Openspot is always on, and has no Edit and no Remove. Its − in Arrange takes it off the grid.

## Get spots in the Store

The Store is the window that shows which spots you have and where they come from. Open it with the Store card,
with "Look in the Store" at the end of a search, or with `openspot store open`.

1. Look at the sidebar. My spots holds each spot you have. A spot that comes with Openspot shows a lock. Under
   Sources come Openspot, the spots that ship with the app, then each folder you added with Add Source….
2. Click a spot. Its page shows its readme, Try with sample data when it has some, and what it uses, runs by itself
   and can also do, before you install it.
3. Drag the spot onto My spots, or press Install on its page. While you drag, My spots says Install, and a source
   says Read only. The review opens, and nothing is copied until its Install.

- The button of a page says Installed once the spot is yours, Update when a newer version waits for your yes, and
  Revert… when you edited it. Update names only what the new version adds. Revert asks before it moves your copy to the
  Trash.
- The search at the top keeps only the spots of the chosen place that match.
- Each act of the Store is also a command, so an agent can do it: `openspot store list`, `store get`, `store update`,
  `store revert`, `store add`, `store remove` and `store open`.

## Change a spot's Settings

Each spot has its own Settings, which open when you press `⌘` Return on its card.

1. Press `⌘` Return on a card. Its Settings list its keys first: Open, the key of each action with a title, and Float.
2. Look further down. Each setting of the spot follows, set or Not set.
3. Look at the end. Show in the menu bar and Open in a window come last.

- A key row records a key on Return, and `⌘⌫` removes it. A key is a shortcut such as `ctrl+option+k`, a shake, or a
  tap of one modifier, such as `option`.
- `openspot setting set` changes the same values: `icon`, `menubar`, `open`, `float` and `key.<action>`, and
  `attachment`, which [the Attachments spot](#hand-what-you-work-on-to-a-spot) sets.

## Choose where a spot shows

Put any spot in the menu bar, in a float or in a window from its Settings.

Arrange the grid in Arrange: press `⌘K` on a card and choose Arrange, press the Spots card, or run `openspot grid edit`.
The screen dims, and your spots that are not on the grid sit in even columns on both sides of the panel, sorted by
name. Type in the field at the top to keep only the matches. Drag a spot onto a free slot to pin it there, drag a card
off the grid to take it off, or drop a spot on a card to swap the two. A lifted spot takes the size of the slot it
lands in. The 4 / 6 / 8 switch sets the columns, and ✓ or Esc ends Arrange. Open the Store, at the bottom, opens the
Store.

For a quick change, hold `⌘` and move the pointer over the grid: drag a card to move it, and its − takes it off. Each
free slot shows a +, and the hint counts your spots that are off the grid. Click a + to pick one of them from a short
list: type to narrow it, and Return pins the chosen spot there. A release of `⌘` ends it. The grid has 7 rows and 4, 6
or 8 columns. Each spot stays at the cell you drop it in. A drop on a smaller hole shrinks the card to fit, and a bigger
card pushes the others on. A spot with no room is found by search, and counts as off the grid.

Type `/spots` to list all your spots, the ones off the grid first. `⌘K` Pin to grid on a row puts that spot in the first
free slot, as `openspot grid pin <id>` does.

- A float shows the spot in a small window at the pointer, which a key or a shake opens, and which stays while you work
  in other apps.
- A window opens the sheet in a normal window, which you move, resize and close.
- A spot with `every` or an action with a title starts off the grid, so a new spot doesn't fill the panel.
- Each spot that comes with Openspot is on, and search finds it. Only the ones Openspot starts with sit on the grid.

## Hand what you work on to a spot

Search for Attachments, and press Return on Selection, Browser Tab or Fresh Copy to hide or show its card in the field.
`⌘` Return opens the Settings of one. Under Access, each app it reads says whether macOS lets Openspot read
it, and Return asks for access or opens the pane of System Settings that gives it. When you open the panel, what each one reads, such as the files you selected in Finder, shows as a small stack of cards on the right of the field. Nothing else
changes until you press Tab.

| Key        | Does                                                                                  |
| ---------- | ------------------------------------------------------------------------------------- |
| Tab        | Shows the front card's preview and each action that takes it, then turns to the next card. |
| `⇧` Tab    | Turns to the card before.                                                             |
| Return     | Runs the selected action with the card, such as Add to Links with a link.             |
| Esc        | Brings back the grid. A second Esc closes the panel.                                  |

- Typing filters the actions that take the card. Backspace edits only the text.
- When the text starts with `/`, Tab completes the slash command instead.
- A card shows only when a spot takes it. Fresh Copy shows what you copied in the last 2 minutes.

Browser Tab reads Safari, Safari Technology Preview, Google Chrome, Google Chrome Canary, Arc, Brave, Microsoft Edge,
Vivaldi and Opera. To read another browser, name its bundle ID and its family, `chromium` or `safari`, in
`~/.config/openspot/config.toml`:

```toml
[browsers]
"company.thebrowser.dia" = "chromium"
"com.kagi.kagimacOS" = "safari"
```

A browser of the Chromium family answers as Chrome does, and one of the Safari family as Safari does. A line for a
browser that Openspot already reads changes its family.

## Rename a slash command

Rename or remove a slash command, or keep a spot out of the search, in `~/.config/openspot/config.toml`. Here `/note`
becomes `/n`, and Notes leaves the search:

```toml
[[spots]]
id = "notes"
search = false
commands = { note = "n" }
```

`""` as the new word removes a command.

## Change the look of Openspot

A theme gives Openspot its colours, glass, sizes, type and motion. Change it to make Openspot look your way.

Open Themes in Openspot, and press Return on a theme to use it. To change one, run `openspot theme open`, which opens
the file of the theme in use, or a copy of `Openspot` the first time. This file gives Openspot the look of Dracula:

```toml
[dark]
background = "#282A36"
ink = "#F8F8F2"
accent = "#BD93F9"
highlight = "#FF79C6"

[light]
background = "#FFFBEB"
ink = "#1F1F1F"
accent = "#644AC9"
highlight = "#A3144D"

[look]
glass = "regular"
backdrop = "tint"
corner = 20
```

Then draw Openspot with it:

```sh
openspot theme reload
```

`[dark]` and `[light]` each hold the colours of one appearance of the Mac, and `[look]` holds the choices of both:

| Key                   | Section             | `Openspot`               | Is                                                       |
| --------------------- | ------------------- | ------------------------ | -------------------------------------------------------- |
| `background`          | `[dark]`, `[light]` | `#000000`, `#FFFFFF`     | The colour of the panel, which tints the glass and the windows. |
| `ink`                 | `[dark]`, `[light]` | `#FFFFFF`, `#1C1C1C`     | The colour of text and glyphs.                           |
| `accent`              | `[dark]`, `[light]` | `accent`                 | The colour of a selection and each chosen state.         |
| `highlight`           | `[dark]`, `[light]` | the `ink`                | The colour of the search field, the keys and a filled card. |
| `good`, `warn`, `bad` | `[dark]`, `[light]` | `green`, `orange`, `red` | The colours of a value that is fine, needs a look, or failed. |
| `glass`               | `[look]`            | `regular`                | `clear` shows what is behind the panel, and `regular` frosts it. |
| `backdrop`            | `[look]`            | `blur`                   | `blur` blurs what is behind the panel, `tint` lays the `background` over it, and `veil` does both. |
| `reach`               | `[look]`            | `tiles`                  | `tiles` lays the backdrop around the tiles, and `screen` covers the screen. |
| `corner`              | `[look]`            | `26`                     | The corner of a card in points, which every other corner follows. |
| `density`             | `[look]`            | `1`                      | A factor on every gap and padding: `0.5` is tight, `1.5` is roomy. |
| `type`                | `[look]`            | `13`                     | The size of the text in points, which other text follows. |
| `speed`               | `[look]`            | `1`                      | A factor on the speed of every motion: `2` is twice as fast. |

- A key that a theme lacks keeps the value of `Openspot`.
- A colour is `#RRGGBB`, `#RRGGBBAA`, or a colour of the Mac: `accent`, `green`, `orange` or `red`.
- `openspot theme reload` prints a line for each value it can't read, and keeps the look as it was.

## Keep more than one theme

Each theme is a folder, `themes/<name>.theme` in the folder of your config, with its `theme.toml` inside.

```sh
openspot theme list
openspot theme new
openspot theme use "Openspot copy"
```

| Command                                   | Does                                                                   |
| ----------------------------------------- | ---------------------------------------------------------------------- |
| `openspot theme use <name>`               | Draws Openspot with a theme.                                           |
| `openspot theme new`                      | Makes `Theme 2`, then `Theme 3`, and uses it.                          |
| `openspot theme duplicate [name]`         | Copies the theme in use, or the named one, as `<name> copy`.           |
| `openspot theme rename <name> <new name>` | Renames a theme.                                                       |
| `openspot theme delete <name>`            | Moves a theme to the Trash.                                            |
| `openspot theme open [name]`              | Opens the file of the theme in use, or the named one.                  |

Openspot comes with built-in themes, such as `Openspot`, `Openspot Liquid` and `Dracula`, which can't change. Duplicate
one to change it.

## Set a value exactly

Set a value exactly when the value that Openspot works out isn't the one you want, such as square windows. Name a colour
or a strength in `[dark]` or `[light]`, and a size, a time or the backdrop in `[advanced]`:

```toml
[dark]
solid = "#FF79C6"
fill = 0.12

[advanced]
window-corner = 6
column-gap = 6
press-bounce = 0
```

| Key                                                                 | Section             | Sets                                                   |
| ------------------------------------------------------------------- | ------------------- | ------------------------------------------------------ |
| `solid`, `on-solid`, `glyph-on-solid`                               | `[dark]`, `[light]` | A filled card, its text and its glyph.                 |
| `glass-tint`, `corner-fill`, `window`                               | `[dark]`, `[light]` | The tint of the glass, the fill behind a corner button, and a window. |
| `confirm`, `on-confirm`                                             | `[dark]`, `[light]` | A press that asks again before it deletes, and its text. |
| `backdrop-tint`, `card-shadow`                                      | `[dark]`, `[light]` | The colour of the backdrop's `tint` and `veil`, and of the shadow under the glass. |
| `fill`, `selected`, `disc`, `chip`, `control`, `track`, `secondary` | `[dark]`, `[light]` | Strengths of the `ink` from 0 to 1, such as the fill of a card. |
| `cell`, `glyph`, `list-row`, `menu-row`                             | `[advanced]`        | The sizes of a grid cell, a glyph, a row and a menu row, in points. |
| `column-gap`, `row-gap`, `padding`, `list-row-gap`, `menu-padding`  | `[advanced]`        | The gaps and paddings in points.                       |
| `window-corner`, `media-corner`, `mark-corner`                      | `[advanced]`        | The corners of a window, a picture and a corner mark.  |
| `title`, `body`, `detail`, `input`                                  | `[advanced]`        | The sizes of the text in points.                       |
| `grow`, `shrink`, `move`, `fade-in`, `fade-out`, `press`, `settle`  | `[advanced]`        | The time of each motion in seconds.                    |
| `press-bounce`, `pressed-scale`, `lifted-scale`, `focused-scale`    | `[advanced]`        | The bounce of a press, and the scale of a card in each state. |
| `backdrop-blur`, `halo-size`, `halo-padding`, `card-shadow-size`    | `[advanced]`        | The blur of the backdrop, how far its halo and the shadow reach. |
| `backdrop-ease`, `halo-roundness`, `halo-inset`                     | `[advanced]`        | How slowly the blur starts across the halo, how fast its corner rounds, and how far under the tiles it reaches full strength. |

A value that follows another follows the exact one too: an exact `solid` gives `on-solid` a colour that reads on it.
