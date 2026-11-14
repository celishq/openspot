import AppKit
import OpenspotCore

@MainActor
enum AppPresence {
    private static var windows = WorkWindows()

    static func open() {
        windows.open()
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }

    static func close() {
        windows.close()
        if !windows.isRegular { NSApp.setActivationPolicy(.accessory) }
    }
}
