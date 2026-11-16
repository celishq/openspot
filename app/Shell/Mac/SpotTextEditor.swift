import AppKit
import UniformTypeIdentifiers

@MainActor
enum SpotTextEditor {
    static func open(_ file: URL) {
        guard let editor = NSWorkspace.shared.urlForApplication(toOpen: .plainText) else {
            NSWorkspace.shared.open(file)
            return
        }
        NSWorkspace.shared.open([file], withApplicationAt: editor, configuration: NSWorkspace.OpenConfiguration())
    }
}
