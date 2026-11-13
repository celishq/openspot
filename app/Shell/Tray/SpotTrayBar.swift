import AppKit
import OpenspotCore
import SwiftUI

/// The menu bar items of the metrics that ask to show there, and running work on the Openspot item. An item comes and goes
/// with its mark, and the Openspot item goes back to its icon, which SwiftUI draws so that a pressed key's symbol can swap in.
@MainActor
final class SpotTrayBar: NSObject {
    /// A view that leaves each click to the button that holds it.
    private final class Host<Content: View>: NSHostingView<Content> {
        override func hitTest(_ point: NSPoint) -> NSView? { nil }
    }

    private final class Shown {
        let item: NSStatusItem
        let host: Host<SpotTrayMarkView>
        /// The mark it draws, so that a mark that did not change is not drawn again.
        var mark: TrayMark?

        init(item: NSStatusItem, host: Host<SpotTrayMarkView>) {
            self.item = item
            self.host = host
        }
    }

    private let model: SpotsModel
    private let openspotItem: NSStatusItem
    private let iconWidth: CGFloat
    private let toast: Toast?
    private var icon: Host<SpotTrayIconView>?
    private var work: Shown?
    private var shown: [String: Shown] = [:]

    init(model: SpotsModel, openspotItem: NSStatusItem, toast: Toast?) {
        self.model = model
        self.openspotItem = openspotItem
        self.toast = toast
        iconWidth = openspotItem.button?.fittingSize.width ?? 0
        super.init()
        icon = makeIcon()
        update()
    }

    /// Moves the image of the Openspot item into a SwiftUI view of the same width.
    private func makeIcon() -> Host<SpotTrayIconView>? {
        guard let button = openspotItem.button, let image = button.image else { return nil }
        button.image = nil
        let host = Host(rootView: SpotTrayIconView(model: model, image: image, toast: toast))
        host.frame = NSRect(x: 0, y: 0, width: iconWidth, height: button.bounds.height)
        host.autoresizingMask = [.width, .height]
        button.addSubview(host)
        return host
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
            icon?.isHidden = false
            openspotItem.button?.toolTip = nil
            openspotItem.button?.setAccessibilityLabel("Openspot")
            openspotItem.length = iconWidth
            return
        }
        icon?.isHidden = true
        let shown = work ?? Shown(item: openspotItem, host: makeHost(mark: mark, in: openspotItem))
        work = shown
        draw(mark, in: shown)
    }

    private func makeHost(mark: TrayMark, in item: NSStatusItem) -> Host<SpotTrayMarkView> {
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
        guard shown.mark != mark else { return }
        shown.mark = mark
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
