import AppKit
import OpenspotCore
import SwiftUI

@MainActor
final class SpotPlayground: NSObject, NSApplicationDelegate {
    private static var kept: Set<SpotPlayground> = []

    private let window: SpotSheetWindow
    private let model: SpotPlaygroundModel
    private var closed: CheckedContinuation<Void, Never>?
    private var watch: NSObjectProtocol?

    private init(path: String?, isCareful: Bool) {
        let model = SpotPlaygroundModel(path: path, isCareful: isCareful)
        self.model = model
        window = SpotSheetWindow.make(title: "Openspot playground", name: "playground-window", size: SpotTokens.playgroundSize, content: SpotPlaygroundView(model: model))
        window.minSize = CGSize(
            width: SpotTokens.playgroundTextWidth + SpotTokens.playgroundStageWidth,
            height: SpotTokens.playgroundTopHeight + SpotTokens.playgroundLogHeight
        )
        super.init()
        watch = NotificationCenter.default.addObserver(forName: NSWindow.willCloseNotification, object: window, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.closeModel() }
        }
    }

    static func run(path: String?) -> Never {
        let app = NSApplication.shared
        let playground = SpotPlayground(path: path, isCareful: false)
        kept.insert(playground)
        app.delegate = playground
        app.setActivationPolicy(.regular)
        EditMenu.install()
        SpotKeyLayouts.start()
        playground.window.show()
        app.run()
        exit(0)
    }

    static func show(path: String?, isCareful: Bool) async {
        let playground = SpotPlayground(path: path, isCareful: isCareful)
        kept.insert(playground)
        playground.window.show()
        await withTaskCancellationHandler {
            await withCheckedContinuation { playground.closed = $0 }
        } onCancel: {
            Task { @MainActor in playground.window.close() }
        }
        kept.remove(playground)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    private func closeModel() {
        model.close()
        watch.map(NotificationCenter.default.removeObserver)
        watch = nil
        closed?.resume()
        closed = nil
    }
}
