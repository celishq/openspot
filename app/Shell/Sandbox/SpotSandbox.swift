import AppKit
import SwiftUI

/// The `openspot sandbox` window, an ordinary window in a process of its own. Closing it ends the process.
@MainActor
final class SpotSandbox: NSObject, NSApplicationDelegate {
    private static var kept: SpotSandbox?

    private let window: NSWindow

    private init(path: String?) {
        let view = NSHostingView(rootView: SpotSandboxView(model: SpotSandboxModel(path: path)))
        window = NSWindow(
            contentRect: NSRect(origin: .zero, size: view.fittingSize),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Openspot sandbox"
        window.contentView = view
        window.center()
        super.init()
    }

    static func run(path: String?) -> Never {
        let app = NSApplication.shared
        let sandbox = SpotSandbox(path: path)
        kept = sandbox
        app.delegate = sandbox
        app.setActivationPolicy(.regular)
        EditMenu.install()
        sandbox.window.makeKeyAndOrderFront(nil)
        app.activate(ignoringOtherApps: true)
        app.run()
        exit(0)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}
