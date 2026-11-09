import AppKit
import SwiftUI

/// The `openspot sandbox` window, an ordinary window in a process of its own, which is also the Try window of a spot.
/// Closing it ends the process. With `OPENSPOT_TRY_PICTURE` it lies off every screen, writes a picture of itself to that
/// path once its reads settle, and exits.
@MainActor
final class SpotSandbox: NSObject, NSApplicationDelegate {
    private static var kept: SpotSandbox?
    private static let pictureSettle = 3.0

    private let window: NSWindow

    private init(path: String?) {
        let model = SpotSandboxModel(path: path)
        let view = NSHostingView(rootView: SpotSandboxView(model: model))
        window = NSWindow(
            contentRect: NSRect(origin: .zero, size: view.fittingSize),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = model.title
        window.contentView = view
        window.center()
        super.init()
    }

    static func run(path: String?) -> Never {
        let app = NSApplication.shared
        let sandbox = SpotSandbox(path: path)
        kept = sandbox
        if let picture = ProcessInfo.processInfo.environment["OPENSPOT_TRY_PICTURE"] { sandbox.draw(to: picture) }
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

    /// Lays the window off every screen, and writes a picture of it once its reads settle.
    private func draw(to path: String) {
        NSApplication.shared.setActivationPolicy(.prohibited)
        window.setFrameOrigin(NSPoint(x: -9000, y: -9000))
        window.orderBack(nil)
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.pictureSettle) { [window] in
            MainActor.assumeIsolated {
                guard let view = window.contentView, let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { exit(1) }
                view.cacheDisplay(in: view.bounds, to: bitmap)
                exit(FileManager.default.createFile(atPath: path, contents: bitmap.representation(using: .png, properties: [:])) ? 0 : 1)
            }
        }
        NSApplication.shared.run()
    }
}
