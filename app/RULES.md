# Rules of the app

These rules are decisions about how this app works that no spot author sees. The spot contract is in
`PROTOCOL.md`, and this file points to its sections, never the other way.
Tests name a rule by its ID, as in `func test_A4_searchStaysUntilEsc`.

## The app

| ID | Rule |
|---|---|
| A1 | One owner in Core starts each run of a script. A capability's helper and a shipped spot's tools are not scripts. |
| A2 | Each script has one sheet model in Core. It holds the last frame, the rows, the parts and the running calls, and each place that shows the script reads from it. A run of one script never stops a run of another. |
| A4 | Search text stays until the person presses Esc. |
| A5 | Spots, New spot, Settings, Updates and Quit ship with the app and answer the same calls, in Swift. |
| A6 | One global key opens the panel, and the person chooses it. A script never holds a key (protocol: The calls). |
| A7 | The person arranges the grid in `config.toml`: order, `size`, `grid`, `enabled`, `global`, which takes a list out of the main search, and `tray`, which puts a spot in the menu bar. It wins over the spot's own header. A size is a preference, and the grid can change it to fill a row. With no choice, the person's files come first, the newest first, then the core spots. |
| A8 | The app opens the panel unseen once as it starts, so that each `panel` read runs. It waits at most 2 seconds, then shows a toast that names the key. |
| A9 | A sheet with no answer yet holds its motion for at most 150 ms, so that it grows once, to its real size. |
| A10 | A dragged `.spot` file shows in the search field, and a drop, a paste or a double-click opens the install screen from there. |
| A11 | The core spots are the spot folders in `spots/` of this repo. They run in place from the app, so an update updates them. Nothing downloads. |
| A12 | A first launch turns on each core spot that reads only local data. Each other core spot is off until the person turns it on. A spot in the spots folder with the same ID wins over a core spot, and is always on. |
| A13 | Spots opens Edit Spots, where the person arranges the grid; the store is a spot of its own. A search for "edit spots" finds Spots. A drag of a card of the store opens Edit Spots under it, which stays after the drag, and a drop on the grid or the shelf adds the spot at the place nearest the drop. |
| A14 | A first launch has no config and no spot, opens the panel on the grid once, and does not open at login. |
| A15 | A toast takes no input, except a failure with a fix (protocol: The life of a call). One fix key, which the person chooses, opens it, and only while the toast shows. |
| A16 | The main search ranks the best match first. Then the most weight of picks, where each pick weighs 0.9 of the one after it, then the spots, then each list in the order of the grid. A list that the person never picked from shows at most 3 rows. |
| A17 | A ⌘ shortcut on a layout whose letters are not Latin, such as Ukrainian, goes by the letter that the same key types in the Latin layout that the Mac keeps for shortcuts, as its menus do. A key with no ⌘ types its own letter. |
| A18 | The panel opens on the screen that holds most of the front window, or with no window in front, on the screen of the pointer. A drag over the menu bar item opens it on the screen of the pointer. It sits as a centred window sits, and an open panel does not move. |
| A19 | A file in the spots folder that gives no spot keeps a card of its faults, with the ID and the place of the spot it stands for, and never a small one. Its sheet shows the file and each fault, with Edit and Copy prompt for AI. Any other fault of a scan shows in a toast. |
| A20 | The app watches the spots folder. A change shows on the cards at once, with no motion, and a changed script that the open panel reads at `panel` reads again. |
| A21 | A spot whose last call failed shows a mark on its card until a call ends well. |
| A24 | Each spot of the person offers Edit, Copy prompt for AI, Share and Delete. A card of a file that does not load offers Edit and Delete. Delete asks no question and keeps the panel open, and `⌘Z` puts the files back until the next Delete. |
| A28 | The actions menu and the right-click menu of a card list only acts on the selected card or row. An act of the whole app is a spot of its own, such as Spots or Settings. |
| A22 | New spot has a small card on the grid after Settings. `⌘N` on the grid or in Edit Spots opens it, unless an action of the selected card takes the key. |
| A23 | New spot is a list that the search field fills. Its first row, Copy prompt for AI, copies a prompt that asks an agent to build what the person typed as a new file in the spots folder, and its toast says so. Openspot starts no agent and writes no file for it. A row for each starter writes a working spot called Untitled and opens its file in the text editor. `⌘K` opens the guide and the spots folder. |
| A29 | The arrows move the focus among the parts of a sheet that a person can use, in the order they are drawn: up and down between lines, to the part closest across, and left and right along a line. Return uses the focused part as a click does, and opens a menu as the system menu. A slider takes left and right, and a field keeps its text keys until its caret reaches its first or last line. Below rows, down on the last row moves to the parts, and up comes back. |
| H1 | The panel keeps a history of the last 20 sheets, each a spot and its page (protocol: Pages). A push drops the sheets ahead, and a page already in it moves to the top. `⌘[`, `⌘]` and a two-finger horizontal swipe move back and forward, Esc clears the search, then goes back one sheet, then closes the sheet, and `⌘Esc` goes back to the grid. A push comes in from the right and a step back from the left. Hiding the panel keeps the history while its sheet stays open. |
| H3 | An edge left of the open sheet stands for each sheet behind it, three at most, the nearest the tallest. A pointer that rests on an edge names its sheet, and a click goes back to it. Horizontal moves stay inside one flow. |
| H2 | A spot has one run for all its pages. A page that leaves the centre keeps its frame, rows and values in the run, shows them at once when it comes back, and reads again. |
| H4 | A spot moves the flow only from a press, one way per frame: a push of any spot, or a pop of its own sheet. A pushed page matches a `pages` line of its spot. A spot never takes off another spot's sheet and never closes the panel; leaving the flow stays with the person (protocol: Pages). |
| M2 | A `panel` or `sheet` moment takes an answer younger than 5 seconds. The open of a sheet that the spot lists in `on=sheet.open` takes only the answer of a sheet open. A change, a number and a wake always read. |
| M3 | Reads run at the same time. The panel never waits for one script. A spot shows its header until its answer arrives. |
| C4 | Openspot waits for a pause before it sends a change of text or of a slider. Text that the person types stays as typed until they press something. |
| K5 | Closing the panel closes a sheet of parts. One with a field the person types in drops its values, and one with none keeps them, so that its next open shows them at once. A sheet of rows stays open. |
| L6 | A call that runs 1 second shows on its part, its action, its spot and the menu bar item, so the person can find and stop it. |
| L7 | When a sheet opens, Openspot reads. A running call shows by its progress on its part, its action and its spot, and its frames change no picture after a later read. |
| L11 | A press within 1 second of the start of a call does nothing, so a double press does not stop it. |
| G1 | A running call shows a ring from the `value` of its last frame, or a spinner with no `value`. |
| G3 | The menu bar item shows the oldest running call and how many run. A click on it opens the panel with that spot selected. |
| G4 | The `title` and `detail` of a call's last frame of only a head show on the spot only while its call runs. |
| G5 | Today's stats stay in memory, and go to `stats/<day>.json` in the config folder at most every 5 seconds and at quit, never on each call. A start reads today's file again, and drops each file older than 90 days (protocol: Stats). |
| D2 | During a drag, only a card whose `drop` takes every dragged file shows it and takes the drop. |
| D6 | A `drop` call runs as any other call does. |
| D5 | A click on a card with `drop` and no sheet opens a file chooser, and the choice runs the same call. A drag over the menu bar item opens the panel with no change of focus, and a drop closes it, unless D8 keeps it. |
| D7 | When a press in another app takes the focus, the panel closes as the press ends. A drag of files that the press starts keeps it open, as a drag over the menu bar item does (D5): the other app keeps the focus, and the panel closes when the drag ends, unless D8 keeps it. |
| D8 | A drop on a card with rows opens its sheet with the focus, and the panel stays open, so the person can act on what the drop added. The sheet holds the focus while the app that the drag came from lets go of it. A drop on any other card closes the panel. |
| K2 | A capability's helper starts at its first call, and exits after 30 seconds with no call. The app does not track it. |
| A25 | A change that the API writes to the config applies only what changed. A key holds the keys again, a spot that turns on or off adds or removes its card, and a value of a spot reads that spot again. The grid does not build again. |
| A26 | An inline spot makes its JavaScript context and its thread at its first call, and drops them after 30 seconds with no call. Its calls go in the call log, the CPU time of its thread counts in `spot stats`, and Review shows its text. |
| A27 | Settings and Updates read with one `openspot` process and no `jq`. |
| A40 | A cache of drawn surfaces holds its base in bytes plus twice its largest value, so that the two parts of the largest surface never push the rest out. |
| A41 | New exchange rates replace kept ones only when they are of the same day or a later one and know at least half as many currencies, so that a broken or old copy of the file never replaces good rates. |
| A42 | Calc asks for exchange rates only for a currency that leaves no doubt: one of a country, bitcoin or ether. A word such as `apr` or `pi` stays a date or a sum. |

## Sharing

A spot travels as its spot folder `<name>.spot`, zipped into one file of the same name. A spot whose widget places or
opens another spot takes that spot's folder too. Hidden files and `$OPENSPOT_DATA` stay behind. Openspot opens a spot
folder and a zip of spot folders. A zip with a path that leaves its folder, a link, or more than the size limit when
unpacked is refused, the last before it unpacks. A file of the same path replaces the old one, which goes to the Trash.

| ID | Rule |
|---|---|
| P4 | Before a person installs a shared spot, Openspot shows all the text it can, says what runs by itself and names each file that it cannot show. Only a modified key installs it. |
| P6 | A `.spot` can carry a Swift script's `<name>.program`, compiled for both kinds of Mac, which runs in its place. The review says first that no one can read it. |
| P7 | Share and publish sign a release of the spot's own folder into its `releases.jsonl` when its files changed since the last release, and keep the log in the spot folder. A forward of files that the last release names keeps that signature. Openspot warns the sender about secrets, and does not look for them. |
| P12 | `releases.jsonl` holds one nostr event a line, the oldest first: kind 30063, the release artifact set of NIP-51. Its `d` tag is `<address>@<version>`, a `file` tag names each file of the folder but the log with its path, SHA-256, size and mode (`755` or `644`), an `e` tag with the marker `previous` names the release before, and its content is the readme. Each event checks by NIP-01, each names the one before it, and the last names exactly the files beside it, or Openspot refuses the spot before the drop. |
| P13 | A release by the key of the last one is the next version of its address. A release by another key starts version 1 of a new address and keeps the log, since a changed copy of another person's spot is a new spot. |
| P14 | The account key comes from 12 BIP-39 words as celis makes it: the BIP-39 seed with no passphrase, then HKDF-SHA256 with salt `celis-identity-v1` and info `account-secp256k1`. The account is the Account spot of `spots/openspot.spot`, with its own view; a Share or publish with no key opens it and stops. Only a spot that ships in the app and declares `uses=account` reaches the key through `openspot account`; the words and a sign-out ask Touch ID, which counts for 5 minutes, and those calls stay out of the call log. A release build keeps the key in the data-protection Keychain, synced through iCloud Keychain, when the app has its Keychain group, and else in the login Keychain. A Debug build or a test keeps it in a file `account` with mode 0600 in its state folder. |
| P15 | The review of a new install says nothing of its signer. Over an installed copy that has a release, it says `Update to version N` when the same key signed it, and else says first that another key signed it. `spots.lock` keeps the address and the key of each signed spot that `spot add` added, and an update from another key waits for `--yes`. |
| P9 | A core spot needs no review, because it is signed with the app. |
| P10 | A publish of a spot of the spots folder writes a copy of its spot folder in `store/` of the config folder, with the program of each Swift script. A spot with no `readme.md` is not published, and a toast asks for one. A spot whose files did not change writes nothing. |
| P11 | A preview is the text that a spot prints with `OPENSPOT_REASON=spot.preview`, on the author's Mac at publish. Drawing a preview runs no code. |

## Floats

A float is one spot in a window of its own, at the pointer, outside the panel.

| ID | Rule |
|---|---|
| W1 | A `[[keys]]` entry with no `command` floats its spot, when its header says `offers=float` (protocol: Places): its sheet, or its card when it has no sheet. An entry with a `command` runs that command. A widget does not float. |
| W2 | `key = "shake"` takes a shake of the pointer in place of a key press: quick turns left and right, with or without a drag. One entry at most holds it, and the app watches the pointer only while one does. The shake needs no permission, because the app reads the pointer and not the keys. `key = "option"`, or another modifier alone, takes a tap of that key: pressed and let go within 0.5 s, with no other key or click between. The app hears a tap only with Accessibility. |
| W3 | Settings lists a Float row on the page of each spot whose header says `offers=float`, beside its commands. Its key records a key press or a shake. |
| W4 | A float opens at the pointer, whole on the pointer's screen. It has no card to grow from, so it shows whole once its first answer comes, or after 150 ms (A9). |
| W5 | A float that opens during a drag does not take the focus, and it stays open through the drop (D7). One that opens with no drag takes the focus, so that its keys work. |
| W6 | A float stays open across apps until Esc, its close button, or a drag of all its files out (protocol: Files out). The same key or shake again closes it, and while a drag holds the mouse button, brings it to the pointer, where the drag needs it. A drag of its background moves it. |
| W7 | Each spot has one float at most. Floats of other spots and the panel show at the same time. A float wants its script as an open sheet does (protocol: Events), and the panel's close does not close it. A float's close drops the values of a sheet of parts with a field, as the panel's close does (K5). |
| W8 | A float takes Up, Down, Return, Esc and the shortcuts of its spot's actions. It has no search field, no `⌘K` menu and no form: an action or a pick that asks with a form, a key or a second press opens the spot in the panel. A pick leaves the float open. |
| W9 | A drop on a float works as a drop on its card (D2, D6). The float shows that it takes a drag only while the pointer lies over it. |
| W10 | A spot whose header says `offers=window` opens its sheet in a titled window of its own, from every open of its sheet, and the panel goes away. It runs as a float does (W7, W8), with the title bar in place of its header, but an action that asks with a form or a second press shows a toast that it does not show yet. The app is a regular app in the Dock and in Command-Tab while any such window is open. |

## Decisions

| Decision | Why | Rejected |
|---|---|---|
| A spot offers a float with `offers=float`, and the person sends it out of the panel by a key or a shake | Settings lists only the spots that offer one, so it stays short, and the script still never learns where it is drawn. | A Float row for every spot, and `command=shake`, which lets a script claim an input. |
| One sheet model for each script | A metric and a sheet both hold what a script last printed, and a widget can place any script. | A separate table and type for metrics. |
| Core spots run in place from the app, from `spots/*.spot` | A first run needs no network, an update updates them, and a diff shows the changed line. | A download, a copy at first launch, `.spot` files in the repo. |
| One progressive backdrop blur close to the cards, under a shade of each theme that fades across the 90 pt margin: black at 20% in dark and at 8% in light. In the dark theme a surface keeps the system material's own fill, tone and saturation | One layer gives a soft edge with no line and no second pass. Side by side with Control Center, the material's own tint gave the cards its lightness and evenness. A blur close to the cards keeps the page behind readable, as in v0.0.7. | Three masked blur steps, which show a line at the window edge. Black at 30% over a bare blur, which can only darken. A blur and a light grey shade spread across the whole margin, which wash the page out. Liquid Glass cards, for their cost on each frame. |
| The panel follows the Mac's appearance. Light mode has near-white bubbles with a hairline edge, dark text and a dark turned-on card | Dark text on a strong white fill reads on any backdrop. A dark turned-on card stays apart from the selection ring. | A look that reacts to what lies behind the panel. An accent turned-on card, which hides the ring. |
| A card in search only keeps its full strength, and Edit Spots shows it on a Search only shelf under the grid, at its grid size | A dim card looks disabled, and it is not; a place says where it shows. | Dimming the card at 40%. A card with no fill. An `eye.slash` mark. |
| A DMG window that shows where to drag, with no background image | The app and Applications side by side say all that a person needs. | An image with an arrow. |
| A signed release is a nostr event of kind 30063 in `releases.jsonl` inside the spot folder, one file tag for each file | Other nostr apps read the kind, a copy from any place checks file by file, and the log shows who released what. | A kind of Openspot's own, a separate signature file, one hash of the zip. |
| A spot is a `<name>.spot` folder everywhere, zipped only when it leaves the Mac | Every editor, agent and git work on its plain files, and one shape serves the spots folder, the core, the store and a share. | Loose files with a JSON `.spot` to share them, and a store package with `listing.toml`. |
| The app moves a loose script into a spot folder of its name | A quick script and an agent's file still work, and the same move is the migration of an older spots folder. | Refusing a loose script with a fault line. |
| A shared file of the same path replaces the old one | A new name would break the IDs that a widget places. | A new name for each clash. |

Each colour, strength and blur radius is in `Shell/Surface/SpotTheme.swift`.

## The protocol

The goals, the rules of the text, the words and the decisions of `PROTOCOL.md`. Each decision names the section
of the protocol that holds its rule.

### Goals

In order. An earlier goal wins when two goals conflict.

1. **A small spot costs almost nothing.** One executable file. No build, no manifest, no account, no SDK.
2. **Openspot draws a spot's data.** A script prints data, and Openspot draws it. A spot can add its own SwiftUI
   view to its spot, and a script can open its own Mac window.
3. **Nothing runs by surprise.** Openspot runs a script only when a person acts or when its header says so.
4. **A spot has real power.** It can use any Mac API, keep state in files, stream a long process and stay running.
5. **A coding agent writes a working spot.** Given only `openspot guide` and one sentence, a coding agent writes a spot
   that passes `openspot check --json` with `[]`, so that it shows on the grid, on its first try. `make eval-agent`
   measures it.

### Rules of the text

1. **Only the contract.** What passes between a script and the host: the header, the arguments, stdin, stdout and the
   environment. Not how the host draws, its keys or its timings, unless a script must be written for a number.
2. **The example first.** One real example, then the rules as short bullets, as Nostr NIPs write them.
3. **Plain words.** Short sentences in ASD-STE100, and MUST, SHOULD and MAY as RFC 2119 gives them. The why of a rule goes
   in the table of decisions, not in the rule.
4. **Each rule once.** The protocol keeps no rule IDs. Code, tests and this file cite a section of it by name.
5. **A decision** that later work must not break goes in the table of decisions, with the one it rejected.
6. **One way to do one thing,** and each word in one place, as the registry shows.

### Registry

| Word                                                                                                     | Kind                 |
| -------------------------------------------------------------------------------------------------------- | -------------------- |
| `title`, `icon`, `detail`, `keyword`, `on`, `emits`, `offers`, `drop`, `size`, `preview`, `view`, `mode`, `uses`, `grid.<size>`, `to` | Header key |
| `button`, `field`                                                                                        | Header block         |
| `once`, `stay`, `always`                                                                                 | Mode                 |
| `app`, `spots`, `screen`, `clipboard`, `calendar`, `network`, `files`                                    | Use                  |
| `search`                                                                                                 | Offer                |
| `sheet.open`, `panel.open`, `clock.<seconds>`, `search.text`, `sheet.text`, `clipboard.change`, `app.front`, `app.update`, `screen.wake` | Event |
| `spot.change`, `spot.want`, `spot.preview`                                                               | Reason with no event |
| `read`                                                                                                   | Reserved call        |
| `open`, `drop`, `drag`                                                                                   | Default id           |
| `OPENSPOT_ID`, `OPENSPOT_REASON`, `OPENSPOT_VALUE`, `OPENSPOT_DATA`, `OPENSPOT_SH`                       | Environment variable |
| `search`, `form`, `value`                                                                                | Stdin key            |
| `openspot <noun> <verb>`, `openspot help <noun>`                                                         | Command              |
| `text`, `number`, `graph`, `picture`, `view`, `switch`, `field`, `choice`, `option`, `button`, `section`, `repeat`, `row` | Block kind |
| `multiline`, `slider`, `hotkey`, `multiple`, `tick`                                                      | Type                 |
| `title`, `detail`, `icon`, `tone`, `value`, `color`, `look`, `align`, `type`                             | Block key            |
| `parent`, `hides`, `keyword`, `shortcut`, `type`, `shake`, `file`, `to`, `pin`, `focus`, `open`, `close`         | Row key              |
| `grid`, `grid.<size>`, `main`, `title`, `detail`, `recents`, `toast`, `link`, `progress`, `select`, `end`, `call`, `search` | Head key    |
| `call`, `arg`, `env.<name>`, `input`, `stop`                                                             | Stdin key of a staying script |

The verbs and the row keys of each `openspot` noun, such as `screen` or `calendar`, are in `openspot help <noun>`.

### Decisions

| Decision                                                                                                    | Rejected                                     |
| ----------------------------------------------------------------------------------------------------------- | -------------------------------------------- |
| One `on` key lists events, and each moment of a read is an event `<noun>.<verb>` with a value (protocol: Events).          | `read` for places, `every` for seconds, `answers` for a pattern and `on` for events. |
| A filter on an event is a regular expression of its value, after a space.                                   | A key for each kind of filter.               |
| The reason of a read is the name of its event.                                                              | A word for each reason beside the events.    |
| A spot names the events that it raises in `emits`, so that a check can know each name (protocol: Events).                | Any word with a dot as an event.             |
| The app's events are default ids, and `read` is the only reserved call.                                     | A verb for each kind of call.                |
| A call is the id, its row and its values; what the person typed is on stdin.                                | The search text and its forms as arguments of `read`. |
| A press of a card with no sheet is `open` with no row.                                                      | A `run` id beside `open`.                    |
| `press=open` lets a spot run at a press and keep its sheet for settings, behind `⌘` (protocol: The main block and the card). | A run button in its sheet, which costs a second press. |
| Return on a spot with one command runs it, and its first Return records the hotkey that each later Return runs (protocol: The header). | Return that opens the hotkey rows, which costs a second press each time. |
| The first key names the kind of a block.                                                                    | A kind found from any key.                   |
| The header is a frame in comments, and its blocks are kinds of the output: `button` and `field`.            | `command` and `setting` blocks of the header alone. |
| Each kind keeps its data in `value`.                                                                        | `point`, `on`, `level` and `text` by kind.   |
| An input is a `field` with a `type`, and a `graph` draws one value or many.                                 | `slider`, `hotkey` and `gauge` as kinds.     |
| A row says that its thing is on by its `value`, and a card by `active` in the head, or by its switch when the switch is the whole card. | `on` in a row and in the head, an `on` tone, and a main `switch`. |
| A frame with a block is the whole picture, and a head alone carries effects.                                | A later frame that merges what it prints.    |
| Escape codes report and never act.                                                                          | OSC 8 as `link`.                             |
| `openspot guide` is the one text of the contract, and a part takes only the keys that it names.             | A catalog of parts beside the guide.         |
| A value is whole, and a thing with its own title or picture is a block.                                     | `<id>:<title>:<icon>` in one value, which a URL or a time such as 09:30 breaks. |
| A person can see and stop each call, so a call has no time limit.                                           | A `job` key.                                 |
| A script runs once for each call, unless its header gives another `mode`, and a `.js` file runs inline (protocol: Modes). | A process that stays by default, and `mode=inline`. |
| A call is the same arguments, variables and stdin in each mode, as CGI and the socket of the API give them (protocol: The calls). | `call=` blocks read with `next`, and a JavaScript function for each id. |
| A helper writes each value from data (protocol: The calls).                                                                  | An author who escapes each value by hand.    |
| The header is in each file, and a scan runs nothing.                                                        | A manifest.                                  |
| The header lists the events where a read is safe, because only the author knows what a read costs.         | `read=true`, with moments that the app picks. |
| A call that needs the app starts it, and a call of files runs where it is (protocol: The openspot command).                           | A process of its own that answers in part, or fails. |
| One call of `openspot batch` asks several things, and `--frame` prints them as frames (protocol: The openspot command).              | A process and a `jq` for each thing.         |
| The person gives each letter, each float and each place in the menu bar, and the header only offers the main search. | `shortcut`, `tray`, `global` and `float` in the header, which two shared spots could both claim. |
| A pattern in the header says which text a spot answers, so a scan learns it with no run, and a key starts no other script. | Each script asked at each key. |
| An answer is a read at `search.text`, so a script has one shape for both.                                   | A new call, such as `answer <text>`.         |
| Answers show first, because they are about the whole text that the person typed.                            | A rank that each spot gives its rows.        |
| A spot runs with the full access of the person, names what it uses in `uses`, and each use shows after it happens (protocol: Trust). | A prompt at each use, a refused call, or a sandbox by default. |
| A spot's call is known by Openspot's own record of its processes (protocol: Trust).                                      | `OPENSPOT_ID` alone, which a process can set or drop. |
| A missing use shows when a run makes it, and `openspot check` does not guess it (protocol: Trust).                      | A check that reads the text for calls.       |
| The person decides at an add or an update, which shows the uses and what grew (protocol: Trust).                     | A review of each call.                       |
| Careful mode is a sandbox that the person turns on, and it allows what `uses` names (protocol: Trust).                  | A data folder that claims to be a boundary.  |
| A script keeps a setting through `openspot setting`, and asks for it when it needs it.                      | A setting with a kind, and required settings. |
| The app owns each canvas, and a drawing only names areas, so each result stays even.                        | Sizes, gaps and colours in points.           |
| A drawing is CSS grid areas, which authors and models know.                                                 | Nested stacks, ratios and named layouts.     |
| A button that no drawing places is an action, so a verb is one kind in two places.                          | An `action` block beside a `button`.         |
| A row draws its own keys, and a richer row is an action or a view.                                          | A template with slots.                       |
| A form is the same call twice, so each call has one shape.                                                  | A `form` word.                               |
| One `main=` names what stands for a spot, so moving a block changes nothing.                                | The first `text`, `gauge` or `switch` of the output, and a `grid.tray` drawing. |
| One `icon` key, whose value says what the picture is.                                                       | `symbol`, `file`, `image` and `glyph`.       |
| A picture on the web is an `icon` URL, which Openspot fetches once and keeps.                               | A script that downloads each picture into `OPENSPOT_DATA`. |
| A look only draws a box, and a kind, a type or a drawing says the rest.                                     | `look=large`, `look=list`, `look=section` and `look=tick`. |
| A complex view is a `view` of the spot in an area, so the text language stays small.                      | More words for each new look.                |
| One Swift file, compiled by Openspot, with no package and no build step.                                    | A Swift package, or a bundle that the author builds. |
| The script holds the state, and the view draws its own block, in Openspot's process.                        | A view that runs its own work or keeps its own data. |
| A card of several spots is a spot whose header draws them by their IDs, and Openspot passes their data.      | A TOML file of widgets, and a spot that reads other spots itself. |
| The header holds the size that a spot prefers, and the person's choice wins.                                | A `size` in the head of a read.              |
| `file` names the file of a row, apart from its id and its picture.                                          | A row id that is a path, which makes the id say two things. |
| `drag` tells the script after the drop, and the script says what stays.                                     | A key that removes a row after a drag.       |
| Openspot drags the file itself, and the other app copies or moves it.                                       | A file promise that the script writes on request. |
| The script never learns where it shows.                                                                     | A call or an environment variable that names the window. |
| A staying script says so in its header, because a script that runs once reads stdin to its end before it answers. | A script that keeps running after its first answer stays. |
| A stop is a block of its own, `stop=<n>`, so no id that an author picks can clash with it.                  | A call named `stop`.                         |
| The script owns its sockets and its peers, and the app owns only stdio.                                     | A network capability in the app.             |

### Open

A stop of a call that `openspot_serve` runs does not end it early, so a slow staying call runs to its end.
