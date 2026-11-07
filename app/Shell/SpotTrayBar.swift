import AppKit
import OpenspotCore
import SwiftUI

/// The menu bar items of the metrics that ask to show there, and running work on the Openspot item. An item comes and goes
/// with its mark, and the Openspot item goes back to its image.
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
    private let openspotItem: NSStatusItem
    private let openspotImage: NSImage?
    private var work: Shown?
    private var shown: [String: Shown] = [:]

    init(model: SpotsModel, openspotItem: NSStatusItem) {
        self.model = model
        self.openspotItem = openspotItem
        openspotImage = openspotItem.button?.image
        super.init()
        update()
    }

    /// Shows the marks of the model now, and again each time they change.
    private func update() {
        let (marks, workMark) = withObservationTracking {
            (model.trayMarks, model.workMark)
        } onChange: { [weak self] in
            Task { @MainActor in self?.update() }
        }
        for id in shown.keys where !marks.contains(where: { $0.id == id }) {
            if let gone = shown.removeValue(forKey: id) { NSStatusBar.system.removeStatusItem(gone.item) }
        }
        for (id, mark) in marks {
            draw(mark, in: shown[id] ?? makeItem(id: id, mark: mark))
        }
        drawWork(workMark)
    }

    /// Shows running work on the Openspot item, in place of its image.
    private func drawWork(_ mark: TrayMark?) {
        guard let mark else {
            work?.host.removeFromSuperview()
            work = nil
            openspotItem.button?.image = openspotImage
            openspotItem.button?.toolTip = nil
            openspotItem.button?.setAccessibilityLabel("Openspot")
            openspotItem.length = NSStatusItem.variableLength
            return
        }
        openspotItem.button?.image = nil
        let shown = work ?? Shown(item: openspotItem, host: makeHost(mark: mark, in: openspotItem))
        work = shown
        draw(mark, in: shown)
    }

    private func makeHost(mark: TrayMark, in item: NSStatusItem) -> Host {
        let host = Host(rootView: SpotTrayMarkView(mark: mark))
        host.sizingOptions = [.intrinsicContentSize]
        host.autoresizingMask = [.width, .height]
        item.button?.addSubview(host)
        return host
    }

    private func makeItem(id: String, mark: TrayMark) -> Shown {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.autosaveName = id
        let host = makeHost(mark: mark, in: item)
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
