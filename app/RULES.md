# Rules of the app

These rules are decisions about how this app works that no plugin author sees. The plugin contract is in `spec/`.
Code and tests name a rule by its ID.

## The app

| ID | Rule |
|---|---|
| A1 | One owner in Core starts each run of a script. A capability's helper and a shipped spot's tools are not scripts. |
| A2 | Each script has one sheet model in Core. It holds the last frame, the rows, the parts and the running calls, and each place that shows the script reads from it. A run of one script never stops a run of another. |
| A4 | Search text stays until the person presses Esc. |
| A5 | Spots, New spot, Settings, Updates and Quit ship with the app and answer the same calls, in Swift. |
| A6 | One global key opens the panel, and the person chooses it. A script never holds a key (P8). |
| A7 | The person arranges the grid in `config.toml`: order, `size`, `grid`, `enabled` and `global`, which takes a list out of the main search. It wins over the plugin. A size is a preference, and the grid can change it to fill a row. With no choice, the person's files come first, the newest first, then the core spots. |
| A8 | The app opens the panel unseen once as it starts, so that each `panel` read runs. It waits at most 2 seconds, then shows a toast that names the key. |
| A9 | A sheet with no answer yet holds its motion for at most 150 ms, so that it grows once, to its real size. |
| A10 | A dragged `.spot` file shows in the search field, and a drop, a paste or a double-click opens the install screen from there. |
| A11 | The core spots are the scripts in `plugins/` of this repo. They run in place from the app, so an update updates them. Nothing downloads. |
| A12 | A first launch turns on each core spot that reads only local data. Each other core spot is off until the person turns it on. A file in the plugins folder with the same ID wins over a core spot, and is always on. |
| A13 | Enter on a row of Spots turns that spot on or off, and keeps the panel open. |
| A14 | A first launch has no config and no plugin, opens the panel on the grid once, and does not open at login. |
| A15 | A toast takes no input, except a failure with a fix (R9). One fix key, which the person chooses, opens it, and only while the toast shows. |
| A16 | The main search ranks the best match first. Then the most weight of picks, where each pick weighs 0.9 of the one after it, then the spots, then each list in the order of the grid. A list that the person never picked from shows at most 3 rows. |
| A17 | A ⌘ shortcut on a layout whose letters are not Latin, such as Ukrainian, goes by the letter that the same key types in the Latin layout that the Mac keeps for shortcuts, as its menus do. A key with no ⌘ types its own letter. |
| A18 | The panel opens on the screen that holds most of the front window, or with no window in front, on the screen of the pointer. A drag over the menu bar item opens it on the screen of the pointer. It sits as a centred window sits, and an open panel does not move. |
| A19 | A file in the plugins folder that gives no spot keeps a card of its faults, with the ID and the place of the spot it stands for, and never a small one. Its sheet shows the file and each fault, with Edit and Copy prompt for AI. Any other fault of a scan shows in a toast. |
| A20 | The app watches the plugins folder. A change shows on the cards at once, with no motion, and a changed script that the open panel reads at `panel` reads again. |
| A21 | A spot whose last call failed shows a mark on its card until a call ends well. |
| A24 | Each spot of the person offers Edit, Copy prompt for AI, Share and Delete. A card of a file that does not load offers Edit and Delete. Delete asks no question and keeps the panel open, and `⌘Z` puts the files back until the next Delete. |
| A22 | New spot has a small card on the grid after Settings, and the first row of Spots opens it too. `⌘N` on the grid or in Edit Spots opens it, unless an action of the selected card takes the key. |
| A23 | New spot is a list that the search field fills. Its first row, Copy prompt for AI, copies a prompt that asks an agent to build what the person typed as a new file in the plugins folder, and its toast says so. Openspot starts no agent and writes no file for it. A row for each starter writes a working spot called Untitled and opens its file in the text editor. `⌘K` opens the guide and the plugins folder. |
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
| D5 | A click on a card with `drop` and no sheet opens a file chooser, and the choice runs the same call. A drag over the menu bar item opens the panel with no change of focus, and a drop closes it, unless D8 keeps it. |
| D7 | When a press in another app takes the focus, the panel closes as the press ends. A drag of files that the press starts keeps it open, as a drag over the menu bar item does (D5): the other app keeps the focus, and the panel closes when the drag ends, unless D8 keeps it. |
| D8 | A drop on a card with rows opens its sheet with the focus, and the panel stays open, so the person can act on what the drop added. The sheet holds the focus while the app that the drag came from lets go of it. A drop on any other card closes the panel. |
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

## Floats

A float is one spot in a window of its own, at the pointer, outside the panel.

| ID | Rule |
|---|---|
| W1 | A `[[keys]]` entry with no `command` floats its spot: its sheet, or its card when it has no sheet. An entry with a `command` runs that command. A widget does not float. |
| W2 | `key = "shake"` takes a shake of the pointer in place of a key press: quick turns left and right, with or without a drag. One entry at most holds it, and the app watches the pointer only while one does. The shake needs no permission, because the app reads the pointer and not the keys. |
| W3 | Settings lists a Float row for each spot that has a card, beside its commands. Its key records a key press or a shake. |
| W4 | A float opens at the pointer, whole on the pointer's screen. It has no card to grow from, so it shows whole once its first answer comes, or after 150 ms (A9). |
| W5 | A float that opens during a drag does not take the focus, and it stays open through the drop (D7). One that opens with no drag takes the focus, so that its keys work. |
| W6 | A float stays open across apps until Esc, its close button, or a drag of all its files out (O3). The same key or shake again brings it to the pointer. A drag of its background moves it. |
| W7 | Each spot has one float at most. Floats of other spots and the panel show at the same time. A float wants its script as an open sheet does (L3), and the panel's close does not close it. A float's close drops the values of a sheet of parts, as the panel's close does (K5). |
| W8 | A float takes Up, Down, Return, Esc and the shortcuts of its spot's actions. It has no search field, no `⌘K` menu and no form: an action or a pick that asks with a form, a key or a second press opens the spot in the panel. A pick leaves the float open. |
| W9 | A drop on a float works as a drop on its card (D2, D6). The float shows that it takes a drag only while the pointer lies over it. |

## Decisions

| Decision | Why | Rejected |
|---|---|---|
| A float is a spot that the person sends out of the panel by a key or a shake | The script never learns where it is drawn, so any spot floats and the contract gains no word. | A `float` or `shelf` header key, and `command=shake`, which let a script claim a place or an input. |
| One sheet model for each script | A metric and a sheet both hold what a script last printed, and a widget can place any script. | A separate table and type for metrics. |
| Core spots run in place from the app, from `plugins/*.sh` | A first run needs no network, an update updates them, and a diff shows the changed line. | A download, a copy at first launch, `.spot` files in the repo. |
| One progressive backdrop blur close to the cards, and a light dark tint that fades across a 90 pt margin, sampled at full scale, with no constant redraw | One layer gives a soft edge with no line and no second pass, and the long fade of the tint shows no shape, as Control Center does. | Three masked blur steps, which show a line at the window edge. A system material and Liquid Glass. |
| The panel follows the Mac's appearance. Light mode has near-white bubbles with a hairline edge, dark text and a dark turned-on card | Dark text on a strong white fill reads on any backdrop. A dark turned-on card stays apart from the selection ring. | A look that reacts to what lies behind the panel. An accent turned-on card, which hides the ring. |
| A hidden card keeps its full strength, and Edit Spots marks it with `eye.slash` | A dim card looks disabled, and it is not. | Dimming the card at 40%. A card with no fill. |
| A DMG window that shows where to drag, with no background image | The app and Applications side by side say all that a person needs. | An image with an arrow. |
| A `.spot` file of JSON: a format number and its files | A chat takes a file of any size, any editor shows JSON, and each header already holds each fact. | Encoded text, a zip, a link. |
| A shared file of the same path replaces the old one | A new name would break the IDs that a widget places. | A new name for each clash. |

Each colour, strength and blur radius is in `Shell/Surface/SpotTheme.swift`.
