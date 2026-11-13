import AppKit
import OpenspotCore
import SwiftUI

/// The menu bar items of the metrics that ask to show there, and running work on the Openspot item. An item comes and goes
/// with its mark.
@MainActor
final class SpotTrayBar: NSObject {
    private let model: SpotsModel
    private let openspotItem: OpenspotItem
    private var shown: [String: MenuBarMarkItem] = [:]

    init(model: SpotsModel, openspotItem: OpenspotItem) {
        self.model = model
        self.openspotItem = openspotItem
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
            if let item = shown[id] { item.draw(mark) } else { shown[id] = makeItem(id: id, mark: mark) }
        }
        openspotItem.show(work: workMark)
    }

    private func makeItem(id: String, mark: TrayMark) -> MenuBarMarkItem {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.autosaveName = id
        item.button?.target = self
        item.button?.action = #selector(press)
        return MenuBarMarkItem(item: item, mark: mark)
    }

    @objc private func press(_ sender: NSStatusBarButton) {
        guard let id = shown.first(where: { $0.value.item.button === sender })?.key else { return }
        model.openFromTray(id)
    }
}
