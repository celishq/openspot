import AppKit
import OpenspotCore

/// The macOS folder window for a script. It gives the picked folder, and nothing on a cancel.
@MainActor
enum SpotFolderPick {
    /// The picked folder on a line, or nothing after Cancel or a stop of the call. The window shows over the panel, and the
    /// app that had the focus gets it back. It waits on the main thread without blocking it.
    static func pick() async -> String {
        let window = NSOpenPanel()
        window.canChooseFiles = false
        window.canChooseDirectories = true
        window.allowsMultipleSelection = false
        window.canCreateDirectories = true
        window.level = .modalPanel
        let previous = NSWorkspace.shared.frontmostApplication.flatMap { $0.processIdentifier == ProcessInfo.processInfo.processIdentifier ? nil : $0 }
        NSApp.activate()
        nonisolated(unsafe) let shown = window
        let response = await withTaskCancellationHandler {
            await withCheckedContinuation { answer in window.begin { answer.resume(returning: $0) } }
        } onCancel: {
            Task { @MainActor in shown.cancel(nil) }
        }
        previous?.activate()
        guard response == .OK, let url = window.url else { return "" }
        return url.path + "\n"
    }
}
