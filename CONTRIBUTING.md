# Contribute to Openspot

Fixes and new plugins are welcome. For a large change, open an issue first.

## Add a plugin

Add one file to [`plugins`](plugins). The [plugin specs](spec/README.md) tell you all that you need.

## Change the app

You need macOS 26, Xcode and [XcodeGen](https://github.com/yonaskolb/XcodeGen).

```sh
brew install xcodegen
cd app && xcodegen generate
open Openspot.xcodeproj
```

A Debug build keeps its plugins and config in `.temp/openspot`, so it does not change your own. Run `make dev-state` to reset them.

Write a failing test first, then the code that passes it. Before you open a pull request, make sure this passes:

```sh
make verify
```

## Follow the rules

- [`AGENTS.md`](AGENTS.md) has the repo conventions.
- [`spec/`](spec) is the plugin contract, and [`app/RULES.md`](app/RULES.md) holds the rules of the app. If your change differs from them, change them first.

By contributing, you agree that your work is under the [MIT License](LICENSE).
