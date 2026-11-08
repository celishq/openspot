# Rules of the app

These rules are decisions about how this app works that no plugin author sees. The plugin contract is in `spec/`.
Code and tests name a rule by its ID.

## The app

| ID | Rule |
|---|---|
| A1 | One owner in Core starts each run of a script. A capability's helper and a shipped spot's tools are not scripts. |
| A2 | Each script has one sheet model in Core. It holds the last frame, the rows, the parts and the running calls, and each place that shows the script reads from it. A run of one script never stops a run of another. |
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
| M2 | A `panel` or `sheet` moment takes an answer younger than 5 seconds. A change, a number, `launch` and `wake` always read. |
| M3 | Reads run at the same time. The panel never waits for one script. A spot shows its header until its answer arrives. |
| C4 | Openspot waits for a pause before it sends a change of text or of a slider. Text that the person types stays as typed until they press something. |
| K5 | Closing the panel closes a sheet of parts and drops its values. A sheet of rows stays open. |
| L6 | A call that runs 1 second shows on its part, its action, its spot and the menu bar item, so the person can find and stop it. |
| L7 | When a sheet opens, Openspot reads, then adds the last frame of each running call. |
| L11 | A press within 1 second of the start of a call does nothing, so a double press does not stop it. |
| G1 | A running call shows a ring from the `value` of its last frame, or a spinner with no `value`. |
| G3 | The menu bar item shows the oldest running call and how many run. A click on it opens the panel with that spot selected. |
| G4 | A frame's `title` and `detail` show on the spot only while its call runs. |
| D2 | During a drag, only a card whose `drop` takes every dragged file shows it and takes the drop. |
| D6 | A `drop` call runs as any other call does. |
| D5 | A click on a card with `drop` and no sheet opens a file chooser, and the choice runs the same call. A drag over the menu bar item opens the panel with no change of focus, and a drop closes it. |
| K2 | A capability's helper starts at its first call, and exits after 30 seconds with no call. The app does not track it. |

## Sharing

A spot travels as a `.spot` file: JSON with `"format": 1` and `files`, a list of `path`, `executable`, and `text` or
`data` in base64. A script in a folder takes the whole folder, and a widget file takes each script that it places or
opens. Hidden files and `$OPENSPOT_DATA` stay behind. A file of the same path replaces the old one, which goes to the
Trash.

| ID | Rule |
|---|---|
| P4 | Before a person installs a shared spot, Openspot shows all the text it can, says what runs by itself and names each file that it cannot show. Only a modified key installs it. |
| P6 | A `.spot` file can carry a Swift script's `<name>.program`, compiled for both kinds of Mac, which runs in its place. The review says first that no one can read it. |
| P7 | A `.spot` file has no signature. Openspot warns the sender about secrets, and does not look for them. |
| P9 | A core spot needs no review, because it is signed with the app. |

## Decisions

| Decision | Why | Rejected |
|---|---|---|
| One sheet model for each script | A metric and a sheet both hold what a script last printed, and a widget can place any script. | A separate table and type for metrics. |
| Core spots run in place from the app, from `plugins/*.sh` | A first run needs no network, an update updates them, and a diff shows the changed line. | A download, a copy at first launch, `.spot` files in the repo. |
| One progressive backdrop blur close to the cards, and a light dark tint that fades across a 90 pt margin, sampled at full scale, with no constant redraw | One layer gives a soft edge with no line and no second pass, and the long fade of the tint shows no shape, as Control Center does. | Three masked blur steps, which show a line at the window edge. A system material and Liquid Glass. |
| The panel follows the Mac's appearance. Light mode has near-white bubbles with a hairline edge, dark text and a dark turned-on card | Dark text on a strong white fill reads on any backdrop. A dark turned-on card stays apart from the selection ring. | A look that reacts to what lies behind the panel. An accent turned-on card, which hides the ring. |
| A hidden card keeps its full strength, and Edit Spots marks it with `eye.slash` | A dim card looks disabled, and it is not. | Dimming the card at 40%. A card with no fill. |
| A DMG window that shows where to drag, with no background image | The app and Applications side by side say all that a person needs. | An image with an arrow. |
| A `.spot` file of JSON: a format number and its files | A chat takes a file of any size, any editor shows JSON, and each header already holds each fact. | Encoded text, a zip, a link. |
| A shared file of the same path replaces the old one | A new name would break the IDs that a widget places. | A new name for each clash. |

Each colour, strength and blur radius is in `Shell/Surface/SpotTheme.swift`.
