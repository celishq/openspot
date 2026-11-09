import AppKit
import OpenspotCore

/// The macOS folder window for a script. It prints the picked folder, and prints nothing on a cancel.
@MainActor
enum SpotFolderPick {
    static func run() -> Never {
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        app.activate(ignoringOtherApps: true)
        let window = NSOpenPanel()
        window.canChooseFiles = false
        window.canChooseDirectories = true
        window.allowsMultipleSelection = false
        window.canCreateDirectories = true
        if window.runModal() == .OK, let url = window.url {
            print(url.path)
        }
        exit(0)
    }
}
