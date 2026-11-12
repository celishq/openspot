import AppKit
import OpenspotCore
import SwiftUI

/// The `openspot sandbox` window, the playground: a window of the running app, or an ordinary window in a process of its own, whose close
/// ends the process.
@MainActor
final class SpotSandbox: NSObject, NSApplicationDelegate, NSWindowDelegate {
    /// The sandbox of a process of its own, and each sandbox that the running app shows.
    private static var kept: Set<SpotSandbox> = []

    private let window: NSWindow
    private let model: SpotSandboxModel
    private var closed: CheckedContinuation<Void, Never>?

    private init(path: String?, isCareful: Bool) {
        model = SpotSandboxModel(path: path, isCareful: isCareful)
        let view = NSHostingView(rootView: SpotSandboxView(model: model))
        window = NSWindow(
            contentRect: NSRect(origin: .zero, size: view.fittingSize),
            styleMask: [.titled, .closable, .miniaturizable],
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

    /// Shows a sandbox in the running app, and returns once the person closes it. A stop of the call closes it.
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
