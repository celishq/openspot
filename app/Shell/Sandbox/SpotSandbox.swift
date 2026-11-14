import AppKit
import OpenspotCore
import SwiftUI

@MainActor
final class SpotSandbox: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private static var kept: Set<SpotSandbox> = []

    private static let size = CGSize(width: 1180, height: 940)

    private let window: NSWindow
    private let model: SpotSandboxModel
    private var closed: CheckedContinuation<Void, Never>?

    private init(path: String?, isCareful: Bool) {
        model = SpotSandboxModel(path: path, isCareful: isCareful)
        let view = NSHostingView(rootView: SpotSandboxView(model: model))
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
        let sandbox = SpotSandbox(path: path, isCareful: false)
        kept.insert(sandbox)
        app.delegate = sandbox
        app.setActivationPolicy(.regular)
        EditMenu.install()
        sandbox.window.makeKeyAndOrderFront(nil)
        app.activate(ignoringOtherApps: true)
        app.run()
        exit(0)
    }

    static func show(path: String?, isCareful: Bool) async {
        let sandbox = SpotSandbox(path: path, isCareful: isCareful)
        kept.insert(sandbox)
        AppPresence.open()
        sandbox.window.makeKeyAndOrderFront(nil)
        await withTaskCancellationHandler {
            await withCheckedContinuation { sandbox.closed = $0 }
        } onCancel: {
            Task { @MainActor in sandbox.window.close() }
        }
        kept.remove(sandbox)
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
