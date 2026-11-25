import AppKit
import OpenspotCore

@MainActor
final class DetachedWindows {
    private let model: SpotsModel
    private var floats: [String: SpotFloatPanel] = [:]
    private var windows: [String: SpotSheetWindow] = [:]
    private var settings: SpotSheetWindow?

    init(model: SpotsModel) {
        self.model = model
    }

    func float(_ entry: SpotsModel.Entry, followsDrag: Bool) {
        let pointer = NSEvent.mouseLocation
        if let shown = floats[entry.id] {
            shown.show(at: pointer, isDragging: followsDrag)
            return
        }
        let window = SpotFloatPanel.make(model: model, id: entry.id)
        floats[entry.id] = window
        Task { @MainActor [model] in
            let end = ContinuousClock.now + .seconds(model.runs.opening.answerPause)
            while model.sheets[entry.id]?.isWaiting == true, ContinuousClock.now < end {
                try? await Task.sleep(for: .milliseconds(10))
            }
            guard floats[entry.id] === window else { return }
            window.contentView?.layoutSubtreeIfNeeded()
            window.show(at: pointer, isDragging: followsDrag)
        }
    }

    func window(_ entry: SpotsModel.Entry) {
        let window = windows[entry.id] ?? SpotSheetWindow.make(model: model, entry: entry)
        windows[entry.id] = window
        window.show()
    }

    func openSettings() {
        let window = settings ?? SpotSheetWindow.make(settings: model, content: SettingsView(model: model))
        settings = window
        window.show()
    }

    func focusSettings() {
        settings?.focus()
    }

    func focus(_ id: String) {
        windows[id]?.focus()
    }

    func land(_ id: String) {
        floats.removeValue(forKey: id)?.orderOut(nil)
        windows.removeValue(forKey: id)?.close()
    }

    func floatTakesDrop(at point: NSPoint) -> Bool {
        floats.values.contains { $0.isVisible && $0.frame.contains(point) }
    }

    var isPointerOverWindow: Bool {
        (Array(windows.values) + [settings].compactMap { $0 }).contains { $0.isVisible && $0.frame.contains(NSEvent.mouseLocation) }
    }
}
