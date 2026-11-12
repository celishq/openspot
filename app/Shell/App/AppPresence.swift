import AppKit
import OpenspotCore

/// How the running app shows itself: a regular app in the Dock and in Command-Tab while a window that the person works in is
/// open, and a menu bar app with none. Each such window opens and closes here.
@MainActor
enum AppPresence {
    private static var windows = WorkWindows()

    /// Makes the app regular and brings it to the front, as a window that the person works in opens.
    static func open() {
        windows.open()
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }

    /// Makes the app a menu bar app again once the last such window closes.
    static func close() {
        windows.close()
        if !windows.isRegular { NSApp.setActivationPolicy(.accessory) }
    }
}
