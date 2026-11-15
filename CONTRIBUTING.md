# Contribute to Openspot

Fixes and new spots are welcome. For a large change, open an issue first.

## Add a spot

Add one spot folder to [`spots`](spots). The [guide](GUIDE.md) shows how, and the [protocol](PROTOCOL.md) gives every rule.

## Change the app

You need macOS 26, Xcode and [XcodeGen](https://github.com/yonaskolb/XcodeGen).

```sh
brew install xcodegen
cd app && xcodegen generate
open Openspot.xcodeproj
```

A Debug build keeps its spots and config in `.temp/openspot`, so it does not change your own. Run `make dev-state` to reset them.

Write a failing test first, then the code that passes it. Before you open a pull request, make sure this passes:

```sh
make verify
```

## Follow the rules

- [`AGENTS.md`](AGENTS.md) has the repo conventions.
- [`GUIDE.md`](GUIDE.md) teaches how to write a spot, and [`PROTOCOL.md`](PROTOCOL.md) is the spot contract. If your change differs from them, change them first.

By contributing, you agree that your work is under the [MIT License](LICENSE).
