import AppKit
import OpenspotCore
import SwiftUI

@MainActor
final class SpotThemeWindow: NSObject, NSWindowDelegate {
    private static var open: SpotThemeWindow?

    private let window: NSWindow
    private let model: SpotThemeModel

    private init(panel: SpotsModel) {
        model = SpotThemeModel(panel: panel)
        window = NSWindow(
            contentRect: NSRect(origin: .zero, size: SpotTokens.themeWindowSize),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "Theme"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isOpaque = false
        window.backgroundColor = .clear
        window.isReleasedWhenClosed = false
        window.minSize = SpotTokens.themeWindowSize
        super.init()
        let host = NSHostingController(rootView: SpotThemeView(model: model) { [weak self] in self?.window.performClose(nil) })
        host.sizingOptions = []
        window.contentViewController = host
        window.setContentSize(SpotTokens.themeWindowSize)
        window.center()
        window.delegate = self
    }

    static func show(model: SpotsModel) {
        let shown = open ?? SpotThemeWindow(panel: model)
        if open == nil {
            open = shown
            AppPresence.open()
        }
        NSApp.activate(ignoringOtherApps: true)
        shown.window.makeKeyAndOrderFront(nil)
    }

    func windowWillClose(_ notification: Notification) {
        model.close()
        Self.open = nil
        AppPresence.close()
    }
}
