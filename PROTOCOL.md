# Openspot protocol

`3.0` `draft`

A spot is a folder with a `spot.toml` and a script, which Openspot runs to show a list, a card or a sheet in its panel.
Openspot calls the script with the name of a handler and the inputs on stdin, and the script answers with lines of
`key=value` on stdout. The pages below give each rule of that contract; to build a spot one task at a time, start with
the [guide](GUIDE.md).

1. [A spot](docs/protocol/01-spot.md): the folder, a call and a frame.
2. [spot.toml](docs/protocol/02-spot-toml.md): its keys and the types of values.
3. [The calls](docs/protocol/03-calls.md): each handler, stdin, the shell helper and how a call ends.
4. [Frames](docs/protocol/04-frames.md): how a frame changes what shows, its root and the kinds of block.
5. [Blocks by kind](docs/protocol/05-blocks.md): the keys of text, numbers, buttons, fields and choices.
6. [Items](docs/protocol/06-items.md): the list, its rows, and pages of a spot.
7. [Actions and settings](docs/protocol/07-actions-and-settings.md): what a spot does and keeps, and forms.
8. [Triggers](docs/protocol/08-triggers.md): `[on]`, the events of the Mac and slash commands.
9. [Bindings and events](docs/protocol/09-bindings-and-events.md): how a spot uses and tells other spots.
10. [Layouts](docs/protocol/10-layout.md): boxes, classes and variants.
11. [Places](docs/protocol/11-places.md): the card, the menu bar and the main search.
12. [Modes](docs/protocol/12-modes.md): a script, a staying spot and a Swift spot.
13. [A JavaScript spot](docs/protocol/13-javascript.md): handlers that run inside Openspot.
14. [Views](docs/protocol/14-views.md): blocks that a SwiftUI file draws.
15. [The openspot command](docs/protocol/15-commands.md): how a spot asks for anything, and timers.

## Versions

The version at the top of this page is the version of the protocol.

- A new word raises the minor number, such as `3.1`, and a change that breaks a spot raises the major number, such as
  `4.0`.
- A `draft` version may still change the meaning of a word. A `final` version never does.
- An older Openspot skips a word of a frame that it doesn't know, and doesn't load a spot whose `spot.toml` has a key
  that it doesn't know.
