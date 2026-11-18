#!/usr/bin/env swift
import AppKit

// Draw is one process that Openspot keeps: it answers the sheet, and it is the board window.
let environment = ProcessInfo.processInfo.environment
guard let data = environment["OPENSPOT_DATA"] else {
    FileHandle.standardError.write(Data("Draw runs inside Openspot, which gives it the folder of its boards.\n".utf8))
    exit(2)
}
// Openspot runs Draw from a file named by a hash, so Draw names itself for the Dock and the menu bar.
ProcessInfo.processInfo.processName = "Draw"
MainActor.assumeIsolated {
    let app = NSApplication.shared
    app.setActivationPolicy(.prohibited)
    let draw = Draw(
        boards: URL(fileURLWithPath: data, isDirectory: true).appendingPathComponent("boards", isDirectory: true),
        home: URL(fileURLWithPath: environment["HOME"] ?? NSHomeDirectory(), isDirectory: true)
    )
    app.delegate = draw
    draw.listen()
    withExtendedLifetime(draw) { app.run() }
}
