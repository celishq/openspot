import AppKit
import OpenspotCore

@MainActor
enum SpotFolderPick {
    static func pick() async -> URL? {
        let window = NSOpenPanel()
        window.canChooseFiles = false
        window.canChooseDirectories = true
        window.allowsMultipleSelection = false
        window.canCreateDirectories = true
        window.level = .modalPanel
        let previous = NSWorkspace.shared.frontmostApplication.flatMap { $0.processIdentifier == ProcessInfo.processInfo.processIdentifier ? nil : $0 }
        NSApp.activate()
        let shown = window
        let response = await withTaskCancellationHandler {
            await withCheckedContinuation { answer in window.begin { answer.resume(returning: $0) } }
        } onCancel: {
            Task { @MainActor in shown.cancel(nil) }
        }
        if !NSApp.windows.contains(where: { $0 is SpotsPanel && $0.isVisible }) { previous?.activate() }
        return response == .OK ? window.url : nil
    }
}
