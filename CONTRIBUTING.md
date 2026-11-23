# Contribute to Openspot

Fixes and new spots are welcome. For a large change, open an issue first.

## Add a spot

Add one spot folder, with its `spot.toml` and its scripts, to [`spots`](spots). [How Openspot works](PROTOCOL.md) shows how, one goal at a time, and its reference gives every rule.

## Change the app

You need macOS 26, Xcode with its Metal Toolchain, and [XcodeGen](https://github.com/yonaskolb/XcodeGen).

```sh
brew install xcodegen
xcodebuild -downloadComponent MetalToolchain
cd app && xcodegen generate
open Openspot.xcodeproj
```

A Debug build keeps its spots and config in `.temp/openspot`, so it does not change your own. Run `make dev-state` to reset them.

Write a failing test first, then the code that passes it. Before you open a pull request, make sure this passes:

```sh
make verify
```

## Extend the protocol

Add a word to the [protocol](PROTOCOL.md) so that an old spot never sees a word it didn't ask for.

| To add               | Add                                                                       |
| -------------------- | ------------------------------------------------------------------------- |
| A thing that happens | An event `<noun>.<verb>`, a key of `[on]` and a handler of its name.      |
| A place to show      | A variant `<place>:`.                                                     |
| A look or a layout   | A class.                                                                  |
| A thing to draw      | A kind `<kind>=`, which an older Openspot skips and reports.              |
| A detail of a kind   | A key, or a `type` value.                                                 |
| A power of the Mac   | A noun, `openspot <noun> <verb>`, with its events and its `uses` word.    |
| A complex look       | Nothing, since a spot draws it with a [view](docs/further/views.md).             |

## Follow the rules

- [`AGENTS.md`](AGENTS.md) has the repo conventions.
- [`PROTOCOL.md`](PROTOCOL.md) and the pages it maps teach how to write a spot and hold the spot contract, and
  [`USING.md`](USING.md) says how to use Openspot. If your change differs from them, change them first.

By contributing, you agree that your work is under the [MIT License](LICENSE).
