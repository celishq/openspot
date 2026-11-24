# Write it in Swift

You'll build Uptime: one row that says how long your Mac has been on, such as "Up for 3 days". It's written in Swift,
in two files.

## Make the folder

`uptime.spot/spot.toml`:

```toml
title = "Uptime"
icon = "clock.arrow.circlepath"
source = ["words.swift"]
```

`uptime.spot/uptime.swift`:

```swift
#!/usr/bin/env swift
import Foundation

let seconds = ProcessInfo.processInfo.systemUptime
if CommandLine.arguments.dropFirst().first == "show" {
    print("item=uptime\ntitle=Up for \(words(seconds))")
}
```

`uptime.spot/words.swift`:

```swift
import Foundation

func words(_ seconds: TimeInterval) -> String {
    let hours = Int(seconds / 3600)
    return hours < 48 ? "\(hours) hours" : "\(hours / 24) days"
}
```

Make the script executable:

```text
chmod +x ~/.config/openspot/spots/uptime.spot/uptime.swift
```

Open Uptime, and its one row says how long the Mac has been on.

## How it works

A Swift spot works like a script. Openspot runs `uptime.swift show`, so the word is in `CommandLine.arguments[1]`, and
the inputs come on stdin as `key=value` lines. The program prints what to show.

Openspot doesn't run the file as a script each time. It builds a program from it once, and runs that program, so each
run starts fast. It builds it again when one of the files changes. Building needs Apple's Command Line Tools; if they're
missing, `xcode-select --install` installs them.

`source` lists the other Swift files the program needs, or folders of them, inside the spot's folder. Only your script
has code at the top level.

## Let Swift check it

```text
openspot types uptime
```

This writes `Openspot.swift` beside your script. It has a type for each input, setting and output of your spot, a
`Handlers` protocol with a function for each word, and a method for each `openspot` command your spot can use. Add it
to `source` to use it.

Start an `openspot` command through `Openspot.swift`, not through Foundation's `Process`. `Process` closes the link
that tells Openspot which spot is asking.

## Next

- [Draw your own view](views.md)
- [Keep your spot running](staying.md)
