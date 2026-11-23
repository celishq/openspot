# Openspot protocol

`3.0` `draft`

A spot is a small tool that Openspot shows in its panel: a folder with a `spot.toml` and a script. Openspot calls the
script with the name of a handler and the inputs on stdin, and the script answers with lines of `key=value` on
stdout. Page 01 is the whole of a working spot, and each later page adds one capability on top of it. To build a spot
one task at a time, start with the [guide](GUIDE.md).

## Pages

| No. | Page                                                | What it adds                                                  | Status              |
| --- | --------------------------------------------------- | ------------------------------------------------------------- | ------------------- |
| 01  | [A spot](docs/protocol/01-spot.md)                  | The folder, calls, frames, and how a call ends.               | `draft` `required`  |
| 02  | [Lists and pages](docs/protocol/02-lists.md)        | The keys of items, the `items` block, and pages of a spot.    | `draft` `optional`  |
| 03  | [Blocks by kind](docs/protocol/03-blocks.md)        | Numbers, charts, pictures, buttons, fields and choices.       | `draft` `optional`  |
| 04  | [Layouts](docs/protocol/04-layouts.md)              | Boxes, classes and variants.                                  | `draft` `optional`  |
| 05  | [Places](docs/protocol/05-places.md)                | The card, the menu bar and the main search.                   | `draft` `optional`  |
| 06  | [Actions](docs/protocol/06-actions.md)              | Things a spot does, with typed inputs and outputs, and forms. | `draft` `optional`  |
| 07  | [Settings](docs/protocol/07-settings.md)            | Choices that the person makes, and secrets.                   | `draft` `optional`  |
| 08  | [Triggers](docs/protocol/08-triggers.md)            | Events of the Mac, clocks, slash commands and drops.          | `draft` `optional`  |
| 09  | [The openspot command](docs/protocol/09-commands.md) | Uses, the commands a spot runs, and timers.                  | `draft` `optional`  |
| 10  | [Other spots](docs/protocol/10-other-spots.md)      | Bindings, runs of another spot's actions, and events.         | `draft` `optional`  |
| 11  | [Modes](docs/protocol/11-modes.md)                  | A staying spot and a Swift spot.                              | `draft` `optional`  |
| 12  | [A JavaScript spot](docs/protocol/12-javascript.md) | Handlers that run inside Openspot.                            | `draft` `optional`  |
| 13  | [Views](docs/protocol/13-views.md)                  | Blocks that a SwiftUI file draws.                             | `draft` `optional`  |

## spot.toml

| Key or table       | Page                                       |
| ------------------ | ------------------------------------------ |
| `title`, `icon`, `detail`, `keywords` | [01](docs/protocol/01-spot.md#spottoml) |
| `pages`            | [02](docs/protocol/02-lists.md#pages)      |
| `answers`          | [05](docs/protocol/05-places.md#the-main-search) |
| `[actions.<id>]`   | [06](docs/protocol/06-actions.md#actionsid) |
| `[settings]`       | [07](docs/protocol/07-settings.md#settings) |
| `[on]`             | [08](docs/protocol/08-triggers.md#on)      |
| `uses`             | [09](docs/protocol/09-commands.md#uses)    |
| `[bindings]`       | [10](docs/protocol/10-other-spots.md#bindings) |
| `[events.<name>]`  | [10](docs/protocol/10-other-spots.md#eventsname) |
| `stay`, `source`   | [11](docs/protocol/11-modes.md)            |
| `views`            | [13](docs/protocol/13-views.md)            |
| `edits`, `starts`  | [The app's own words](spots/AGENTS.md#the-apps-own-words) |

## Handlers

| Call                       | Page                                               |
| -------------------------- | -------------------------------------------------- |
| `show`, `press`            | [01](docs/protocol/01-spot.md#the-calls)           |
| `drag`                     | [02](docs/protocol/02-lists.md#items)              |
| `search`                   | [05](docs/protocol/05-places.md#the-main-search)   |
| `<action>`                 | [06](docs/protocol/06-actions.md#actionsid)        |
| `<setting>`                | [07](docs/protocol/07-settings.md#settings)      |
| `every`, `schedule`        | [08](docs/protocol/08-triggers.md#a-clock)         |
| `command`                  | [08](docs/protocol/08-triggers.md#slash-commands)  |
| `drop`                     | [08](docs/protocol/08-triggers.md#drop)            |
| `<event>`                  | [08](docs/protocol/08-triggers.md#events)          |
| `<binding>.<event>`        | [10](docs/protocol/10-other-spots.md#eventsname)   |

## Root keys

| Key                                         | Page                                      |
| ------------------------------------------- | ----------------------------------------- |
| `frame`, `title`, `detail`, `progress`, `error` | [01](docs/protocol/01-spot.md#the-root) |
| `recents`                                   | [02](docs/protocol/02-lists.md#items)     |
| `class`                                     | [04](docs/protocol/04-layouts.md#boxes)   |
| `value`, `active`                           | [05](docs/protocol/05-places.md#the-card) |
| `type`, `out.<name>`                        | [06](docs/protocol/06-actions.md)         |
| `call`, `end`                               | [11](docs/protocol/11-modes.md#a-staying-spot) |
| `shown`                                     | [The app's own words](spots/AGENTS.md#the-apps-own-words) |

## Block kinds

| Kind                                   | Page                                           |
| -------------------------------------- | ---------------------------------------------- |
| `item`                                 | [01](docs/protocol/01-spot.md#blocks), [02](docs/protocol/02-lists.md#items) |
| `items`                                | [02](docs/protocol/02-lists.md#the-items-block) |
| `text`, `number`, `series`, `icon`, `picture` | [03](docs/protocol/03-blocks.md#words-and-values) |
| `button`                               | [03](docs/protocol/03-blocks.md#buttons)       |
| `field`, `switch`, `choice`, `option`  | [03](docs/protocol/03-blocks.md#inputs)        |
| `box`                                  | [04](docs/protocol/04-layouts.md#boxes)        |
| A view, named by its file              | [13](docs/protocol/13-views.md)                |

## Class families

| Family                                                    | Page                                       |
| --------------------------------------------------------- | ------------------------------------------ |
| Boxes, grids and layers: `flex-row`, `grid`, `relative`   | [04](docs/protocol/04-layouts.md#classes)  |
| Place and space: `items-center`, `p-3`, `gap-2`, `w-16`   | [04](docs/protocol/04-layouts.md#classes)  |
| Words: `font-title`, `truncate`, `text-accent`            | [04](docs/protocol/04-layouts.md#classes)  |
| Fills, edges and corners: `bg-tile`, `border`, `rounded-full` | [04](docs/protocol/04-layouts.md#classes) |
| States and looks: `hover:`, `selected:`, `dark:`          | [04](docs/protocol/04-layouts.md#variants) |
| Places and card sizes: `card:`, `bar:`, `wide:`           | [05](docs/protocol/05-places.md)           |

## openspot nouns

| Noun                                          | Page                                           |
| --------------------------------------------- | ---------------------------------------------- |
| `spot`, `check`, `playground`, `schema`       | [01](docs/protocol/01-spot.md#try-your-spot)   |
| `route`                                       | [02](docs/protocol/02-lists.md#pages)          |
| `setting`, `folder`                           | [07](docs/protocol/07-settings.md)             |
| `toast`, `select`, `timer`                    | [09](docs/protocol/09-commands.md)             |
| `run`, `emit`                                 | [10](docs/protocol/10-other-spots.md)          |
| `types`                                       | [11](docs/protocol/11-modes.md#a-swift-spot), [12](docs/protocol/12-javascript.md) |
| Each other noun, such as `clipboard` or `window` | [The openspot commands](app/Help/commands.md) |

## Versions

The version at the top of this page is the version of the protocol.

- A new word raises the minor number, such as `3.1`, and a change that breaks a spot raises the major number, such as
  `4.0`.
- A `draft` version may still change the meaning of a word. A `final` version never does.
- An older Openspot skips a word of a frame that it doesn't know, and doesn't load a spot whose `spot.toml` has a key
  that it doesn't know.
