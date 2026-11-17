import AppKit
import OpenspotCore
import SwiftUI

@MainActor
final class SpotThemeWindow {
    private static var open: SpotThemeWindow?

    private let window: SpotSheetWindow
    private let model: SpotThemeModel
    private var watches: [NSObjectProtocol] = []

    private init(panel: SpotsModel) {
        let model = SpotThemeModel(panel: panel)
        self.model = model
        window = SpotSheetWindow.make(title: "Theme", name: "theme-window", size: SpotTokens.themeWindowSize, content: SpotThemeView(model: model))
        window.minSize = CGSize(width: SpotTokens.themeWindowSize.width, height: SpotTokens.themeWindowMinHeight)
        let center = NotificationCenter.default
        watches = [
            center.addObserver(forName: NSWindow.didBecomeKeyNotification, object: window, queue: .main) { _ in
                MainActor.assumeIsolated { model.refresh() }
            },
            center.addObserver(forName: NSWindow.willCloseNotification, object: window, queue: .main) { _ in
                MainActor.assumeIsolated { Self.closed() }
            }
        ]
    }

    static func show(model: SpotsModel) {
        let shown = open ?? SpotThemeWindow(panel: model)
        open = shown
        shown.window.show()
    }

    private static func closed() {
        guard let shown = open else { return }
        shown.model.close()
        shown.watches.forEach(NotificationCenter.default.removeObserver)
        open = nil
    }
}
