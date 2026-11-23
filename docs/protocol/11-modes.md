# Modes

`draft` `optional` · Builds on [01](01-spot.md)

Use this when a process for each call doesn't fit your spot: when it should keep what it holds between calls, or be a
Swift program. A mode is the way Openspot runs a spot's script, and the script's file chooses it.

| Mode                                  | Chosen by                                | Is                                  |
| ------------------------------------- | ---------------------------------------- | ----------------------------------- |
| A script                              | an executable file                       | A process for each call.            |
| [A staying spot](#a-staying-spot)     | `stay = true` in `spot.toml`             | One process that answers each call. |
| [A JavaScript spot](12-javascript.md) | a `.js` file with no execute permission  | Code that runs inside Openspot.     |
| [A Swift spot](#a-swift-spot)         | a Swift file with `#!/usr/bin/env swift` | A program that Openspot builds once. |

## A staying spot

A staying spot is one process that gets each call on its stdin and answers on its stdout, so it keeps what it holds
between calls. `stay` in `spot.toml` makes one.

```toml
title = "CPU trend"
icon = "cpu"
stay = true

[on]
"sheet.open" = true
"system.load" = true
```

```sh
#!/bin/sh
. "$OPENSPOT_SH"
points=
main() {
  load=$(value value)
  case "$load" in
    cpu=*) now=${load#cpu=} && points="$points,${now%% *}" ;;
  esac
  printf 'frame=\nclass=gap-part\n\nseries=cpu\ntitle=CPU\nvalue=%s\nmax=100\nunit=%%\nclass=h-32\n' "${points#,}"
}
openspot_serve main "$@"
```

Every 5 seconds the chart gains a bar, and it keeps its bars when the panel closes and opens again.

- `openspot_serve` runs `main` with the arguments and stdin of each call, so the same script also works as a script.
- The process runs while one of the spot's places shows, or from launch to quit with `"app.launch" = true` in `[on]`.
- When no place shows it, Openspot closes its stdin. The spot MUST then end, with each process it started.
- A second press of a running call stops it.

A program that doesn't use `openspot_serve` reads each call as one block on stdin: `call=<n>`, an `arg` line with the
handler's name, then the inputs. It prints a root with `call=<n>` before its answer and `end=<n>` after it. A stop
comes as `stop=<n>`.

## A Swift spot

A Swift spot is a program that Openspot builds once from the spot's Swift files, and runs at each call.

```toml
title = "Cups today"
icon = "cup.and.saucer.fill"
source = ["cups.swift"]
```

`cups-today.swift`, the script:

```swift
#!/usr/bin/env swift
print("item=cups\ntitle=\(cups) cups")
```

`cups.swift`, which `source` names:

```swift
let cups = 3
```

The sheet shows one row, 3 cups.

- The program gets the handler's name in `CommandLine.arguments[1]`, and the inputs on stdin, as a script does.
- `source` lists more Swift files or folders of the spot folder.
- Openspot builds it with the Command Line Tools, and again when a file changes.
- `openspot types` writes `Openspot.swift` beside the script, with a typed method for each handler. List it in
  `source`.
- The program MUST start each `openspot` command with `posix_spawn`, since Foundation's `Process` closes the link to
  Openspot.
