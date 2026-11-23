# Use Openspot

This page is for the person who uses Openspot. It shows how to reach a spot with its keys, choose where it shows, and
change the look of Openspot. A spot can't choose these for you, so every spot works in any place and with any key.

## Use the keys of a spot

Every spot answers the same keys, so you learn them once.

| Key        | Does                                                                                        |
| ---------- | ------------------------------------------------------------------------------------------- |
| Return     | The main action of the spot: it runs the spot's one action with a title, or opens its sheet. |
| `⌘` Return | Opens the spot's Settings: its keys, each setting and its places.                           |
| `⌘Y`       | Opens the items of a spot whose Return runs its action, as its History.                     |
| `⌘K`       | Opens the menu of all actions, when it holds more than the footer shows.                    |

- A spot with one action with a title, such as Dictate, runs that action on Return, even before it has a key of its
  own. Its items are its History, on `⌘Y` and in its ⌘K menu. Any other spot opens its sheet on Return.
- A press of its card, its open key, a click of it in the menu bar and its slash command with no text do what Return
  does. A click in the menu bar opens the sheet under the menu bar item.
- A press with `⌘` opens the spot's Settings.
- The ⌘K menu of a card starts with the actions that Openspot adds, always in this order: first what you do with the
  spot, the main action on Return, History and Share; then what changes it, Settings, Edit and Change Icon; then Turn
  off or a red Delete.
- The actions that Openspot's own spots offer to every card follow, under the name of their spot.
- A card's `⌘` keys work while a search is typed, except the ones that edit the words, such as `⌘⌫`.
- Edit copies a prompt that sends an agent to the spot's file. You change a spot there, not in its Settings.
- A card shows an arrow when Return opens its sheet, and none when Return runs its action. The footer names the spot's
  own keys first and `⌘K Actions` last.

## Change a spot's Settings

Each spot has its own Settings, a sheet that grows from its card when you press `⌘` Return on it.

1. Press `⌘` Return on a card. Its Settings list its keys first: Open, the key of each action with a title, and Float.
2. Look further down. Each setting of the spot follows, set or Not set, and each value it keeps that no setting names,
   such as a look.
3. Look at the end. Show in the menu bar and Open in a window, which every spot has, come last.

- Each key row records a key on Return, and `⌘⌫` removes it. A key is a shortcut such as `ctrl+option+k`, a shake, or
  one modifier alone, such as `option`, which a tap of that key presses.
- The key of Open does what a press of the spot's card does, from any app.
- Return on a setting that Openspot can't keep by itself, such as a text, runs the spot, which can answer with a form.
  `⌘⌫` removes its value.
- `openspot setting set` changes the same values. Of any spot, they are `icon`, the picture that Change Icon keeps;
  `enabled` and `menubar`, `true` or `false`; and `open`, `float` and `key.<action>`, a key.
- Of the spot `openspot`, which is the app, they are `login`, `link`, `careful` and `slow`, `true` or `false`, and
  `panel-key` and `fix-key`.
- The Settings spot of Openspot holds only the settings of the app: its keys, Careful mode, Slow motion, Open at login
  and the `openspot` command. Slow motion runs each motion of the panel ten times slower until the app quits.

## Choose where a spot shows

Put any spot on the grid, in the menu bar, in a float or in a window, from its Settings and from Edit Spots.

- A float shows the spot in a small window at the pointer, which a key or a shake of the pointer opens, and which stays
  while you work in other apps.
- A window opens the sheet in a normal window, from the card, the main search or `openspot spot open`. You move,
  resize and close it, and Openspot shows in the Dock while it's open. Esc closes it too.
- A spot with `every` or an action with a title starts off the grid, so that a new spot doesn't fill the panel.
- A spot of your spots folder with a `schedule` acts by itself, so it starts off until you press Get on it in the Store.

## Rename a slash command

Rename or remove a slash command of a spot, or keep a spot out of the main search, in the spot's record of
`~/.config/openspot/config.toml`. Here `/note` becomes `/n`, and Notes leaves the main search:

```toml
[[spots]]
id = "notes"
search = false
commands = { note = "n" }
```

- `commands` maps each word of the spot to the word you type, and `""` removes the word.
- `search = false` keeps the spot out of the main search and out of the list of slash commands.

## Change the look of Openspot

A theme gives Openspot its colours, glass, sizes, type and motion. Change it to make Openspot look your way.

Open Themes in Openspot to see each theme, with the one in use checked. Return uses a theme. Its ⌘K menu duplicates,
renames, moves to the Trash or opens the file of a theme, and Copy prompt hands a theme to your agent: describe the
look you want, and `⌘⏎` copies a prompt that changes the theme's file. The same prompt comes from
`openspot prompt theme <name> [words]...`.

Each theme lives in one file, `theme.toml`. Run `openspot theme open`, which opens the file of the theme in use, and the
first time makes a copy of `Openspot`, `Openspot copy`, and uses it. A theme names a few colours and choices, and
Openspot works out every other value from them. This one gives Openspot the look of Dracula:

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

| Key                   | Section             | `Openspot`               | Is                                                                     |
| --------------------- | ------------------- | ------------------------ | ---------------------------------------------------------------------- |
| `background`          | `[dark]`, `[light]` | `#000000`, `#FFFFFF`     | The colour of the panel, which tints the glass, the backdrop and the windows. |
| `ink`                 | `[dark]`, `[light]` | `#FFFFFF`, `#1C1C1C`     | The colour of text and glyphs.                                         |
| `accent`              | `[dark]`, `[light]` | `accent`                 | The colour of a selection, its ring and each chosen state.             |
| `highlight`           | `[dark]`, `[light]` | the `ink`                | The colour of the search field, the keys, the sliders and a filled card. |
| `good`, `warn`, `bad` | `[dark]`, `[light]` | `green`, `orange`, `red` | The colours of a value that is fine, needs a look, or failed.          |
| `glass`               | `[look]`            | `regular`                | How the glass shows what is behind the panel: `clear` or `regular`.    |
| `backdrop`            | `[look]`            | `blur`                   | How the backdrop shows what is behind the panel: `blur` or `tint`.     |
| `reach`               | `[look]`            | `tiles`                  | How far the backdrop reaches: `tiles` or `screen`.                     |
| `corner`              | `[look]`            | `26`                     | The corner of a card in points, which every other corner follows.     |
| `density`             | `[look]`            | `1`                      | A factor on every gap and padding: `0.5` is tight, `1.5` is roomy.     |
| `type`                | `[look]`            | `13`                     | The size of the text in points, which smaller and larger text follows. |
| `speed`               | `[look]`            | `1`                      | A factor on the speed of every motion: `2` is twice as fast.           |

- `bad` also marks a press that deletes.
- `glass`: `clear` shows what is behind the panel, and `regular` frosts it, with the `background` tinting it strongly.
- `backdrop`: `blur` blurs what is behind the panel, and `tint` lays the `background` over it.
- `reach`: `tiles` lays the backdrop as a soft halo around the tiles, and `screen` covers the screen.
- `corner`: at 26, a card one row high is a capsule, and a smaller corner makes it squarer.
- A key that a theme lacks keeps the value of `Openspot`, so a theme needs only the keys you change.
- A colour is `#RRGGBB`, `#RRGGBBAA`, or a colour of the Mac: `accent`, `green`, `orange` or `red`.
- Openspot works out each other value, such as the fill of a card, from these keys. The fills keep the same visible step
  over any `background`, and the second line of a row stays readable over it, at 4.5:1 or more.
- After `openspot theme reload`, colours and the glass change at once. Corners, density, type, speed and the backdrop
  change when the panel next hides.
- `openspot theme reload` fails on a value it can't read, prints a line for each, such as
  `theme.toml: [look] corner is a number of points from 0 to 100, such as 3.`, and keeps the look as it was.
- At launch, a value that Openspot can't read keeps the value of `Openspot`, and a toast shows the line. A key that is
  not on this page is such a value.

## Keep more than one theme

Keep more than one theme to switch between looks. Each theme is a folder, `themes/<name>.theme` in the folder of your
config, named by the folder, with its `theme.toml` inside:

```sh
openspot theme list
openspot theme new
openspot theme use "Openspot copy"
```

`list` prints a block for each theme, the built-in ones first, and marks the one in use:

```text
theme=Openspot
builtin=true

theme=Openspot copy
used=true
```

| Command                                   | Does                                                                                     |
| ----------------------------------------- | ---------------------------------------------------------------------------------------- |
| `openspot theme use <name>`               | Draws Openspot with a theme.                                                             |
| `openspot theme new`                      | Makes `Theme 2`, then `Theme 3`, and uses it.                                            |
| `openspot theme duplicate [name]`         | Copies the theme in use, or the named one, as `<name> copy`, and uses the copy.          |
| `openspot theme rename <name> <new name>` | Renames a theme.                                                                         |
| `openspot theme delete <name>`            | Moves a theme to the Trash.                                                              |
| `openspot theme open [name]`              | Opens the file of the theme in use, or the named one, and copies a built-in theme first. |

- `openspot theme new`: its file lists each key behind a `#`, and you remove the `#` to change one.
- `openspot theme delete`: deleting the theme in use switches to `Openspot`.
- `openspot theme use` fails on a theme with a value it can't read, prints a line for each, and keeps the theme in use.
- A theme in use that is gone gives a toast at launch, and Openspot draws with `Openspot`.
- Openspot comes with built-in themes, such as `Openspot`, with frosted glass, `Openspot Liquid`, the same look with
  clear glass, and `Dracula`. Until you choose one, Openspot uses `Openspot Liquid` on macOS 26 and `Openspot` on a later
  macOS.
- A built-in theme can't change, be renamed or be deleted: `openspot theme duplicate` makes a copy of it that you can
  change.
- A name can't be empty, start with `.`, or hold `/` or a new line, and the spaces around it are dropped.
- A folder that has the name of a built-in theme, in any case, is not a theme, and a toast at launch asks you to rename
  it.

## Set a value exactly

Set a value exactly when the value that Openspot works out is not the one you want, such as square windows on a theme
with small corners. Name the value in `[dark]` or `[light]` for a colour or a strength of one appearance, and in
`[advanced]` for a size, a time or the backdrop:

```toml
[dark]
solid = "#FF79C6"
fill = 0.12

[advanced]
window-corner = 6
column-gap = 6
press-bounce = 0
```

| Key                                                                 | Section             | Sets                                                                                    |
| ------------------------------------------------------------------- | ------------------- | --------------------------------------------------------------------------------------- |
| `solid`, `on-solid`, `glyph-on-solid`                               | `[dark]`, `[light]` | A filled card, its text and its glyph, which follow `highlight`.                        |
| `glass-tint`, `corner-fill`, `window`                               | `[dark]`, `[light]` | The tint of the glass, the fill behind a corner button, and a lifted card and a window, which follow `background`. |
| `confirm`, `on-confirm`                                             | `[dark]`, `[light]` | A press that asks again before it deletes, and its text, which follow `bad`.            |
| `backdrop-tint`                                                     | `[dark]`, `[light]` | The colour of the backdrop `tint`, which follows `background`.                          |
| `card-shadow`                                                       | `[dark]`, `[light]` | The colour of the soft shadow under each glass surface, whose alpha is its strength.    |
| `fill`, `selected`, `disc`, `chip`, `control`, `track`, `secondary` | `[dark]`, `[light]` | Strengths from 0 to 1 of the `ink`: the field and a card, a chosen row, the disc behind a glyph, a chip, a button, a track and ring, and the second line of a row. |
| `cell`, `glyph`, `list-row`, `menu-row`                             | `[advanced]`        | The side of a grid cell, of a glyph, and the height of a row and a menu row, in points. |
| `column-gap`, `row-gap`, `padding`, `list-row-gap`, `menu-padding`  | `[advanced]`        | The gaps and paddings in points, which follow `density`.                                |
| `window-corner`, `media-corner`, `mark-corner`                      | `[advanced]`        | The corners of a window, a picture and a corner mark, which follow `corner`.            |
| `title`, `body`, `detail`, `input`                                  | `[advanced]`        | The sizes of the text in points, which follow `type`.                                   |
| `grow`, `shrink`, `move`, `fade-in`, `fade-out`, `press`, `settle`  | `[advanced]`        | The time of each motion in seconds, which follow `speed`.                               |
| `press-bounce`, `pressed-scale`, `lifted-scale`, `focused-scale`    | `[advanced]`        | The bounce of a press, and the scale of a pressed, a lifted and a focused card.         |
| `backdrop-blur`, `halo-size`, `halo-padding`                        | `[advanced]`        | The strength of the backdrop's blur, how far its halo reaches past the tiles, from 16 to 90, and how far it holds its full strength, from 0 to 74. |
| `card-shadow-size`                                                  | `[advanced]`        | How far the shadow under each glass surface spreads, in points.                         |

- An exact value holds only in the file that sets it. A copy of `Openspot` keeps the exact values in its file, but a
  theme you write from scratch works out its own.
- A value that follows another follows the exact one too: an exact `solid` gives `on-solid` the colour that reads on it.
