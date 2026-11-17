import AppKit
import OpenspotCore
import SwiftUI

@MainActor
final class SpotPlayground: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private static var kept: Set<SpotPlayground> = []

    private static let size = CGSize(width: 1180, height: 940)

    private let window: NSWindow
    private let model: SpotPlaygroundModel
    private var closed: CheckedContinuation<Void, Never>?

    private init(path: String?) {
        model = SpotPlaygroundModel(path: path)
        let view = NSHostingView(rootView: SpotPlaygroundView(model: model))
        window = NSWindow(
            contentRect: NSRect(origin: .zero, size: Self.size),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Openspot playground"
        window.contentView = view
        window.isReleasedWhenClosed = false
        window.center()
        super.init()
        window.delegate = self
    }

    static func run(path: String?) -> Never {
        let app = NSApplication.shared
        let playground = SpotPlayground(path: path)
        kept.insert(playground)
        app.delegate = playground
        app.setActivationPolicy(.regular)
        EditMenu.install()
        SpotKeyLayouts.start()
        playground.window.makeKeyAndOrderFront(nil)
        app.activate(ignoringOtherApps: true)
        app.run()
        exit(0)
    }

    static func show(path: String?) async {
        let playground = SpotPlayground(path: path)
        kept.insert(playground)
        AppPresence.open()
        playground.window.makeKeyAndOrderFront(nil)
        await withTaskCancellationHandler {
            await withCheckedContinuation { playground.closed = $0 }
        } onCancel: {
            Task { @MainActor in playground.window.close() }
        }
        kept.remove(playground)
        AppPresence.close()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    func windowWillClose(_ notification: Notification) {
        model.close()
        closed?.resume()
        closed = nil
    }
}
