import AppKit
import OpenspotCore
import SwiftUI

/// The menu bar items of the widgets that show a metric there. An item comes and goes with its mark.
@MainActor
final class SpotTrayBar: NSObject {
    /// A view that leaves each click to the button that holds it.
    private final class Host: NSHostingView<SpotTrayMarkView> {
        override func hitTest(_ point: NSPoint) -> NSView? { nil }
    }

    private struct Shown {
        let item: NSStatusItem
        let host: Host
    }

    private let model: SpotsModel
    private var shown: [String: Shown] = [:]

    init(model: SpotsModel) {
        self.model = model
        super.init()
        update()
    }

    /// Shows the marks of the model now, and again each time they change.
    private func update() {
        let marks = withObservationTracking {
            model.trayMarks
        } onChange: { [weak self] in
            Task { @MainActor in self?.update() }
        }
        for id in shown.keys where !marks.contains(where: { $0.id == id }) {
            if let gone = shown.removeValue(forKey: id) { NSStatusBar.system.removeStatusItem(gone.item) }
        }
        for (id, mark) in marks {
            draw(mark, in: shown[id] ?? makeItem(id: id, mark: mark))
        }
    }

    private func makeItem(id: String, mark: TrayMark) -> Shown {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.autosaveName = id
        let host = Host(rootView: SpotTrayMarkView(mark: mark))
        host.sizingOptions = [.intrinsicContentSize]
        host.autoresizingMask = [.width, .height]
        item.button?.addSubview(host)
        item.button?.target = self
        item.button?.action = #selector(press)
        let new = Shown(item: item, host: host)
        shown[id] = new
        return new
    }

    private func draw(_ mark: TrayMark, in shown: Shown) {
        shown.host.rootView = SpotTrayMarkView(mark: mark)
        let width = ceil(shown.host.fittingSize.width)
        shown.item.length = width
        shown.host.frame = NSRect(x: 0, y: 0, width: width, height: shown.item.button?.bounds.height ?? 0)
        shown.item.button?.toolTip = mark.summary
        shown.item.button?.setAccessibilityLabel(mark.summary)
    }

    @objc private func press(_ sender: NSStatusBarButton) {
        guard let id = shown.first(where: { $0.value.item.button === sender })?.key else { return }
        model.openFromTray(id)
    }
}
