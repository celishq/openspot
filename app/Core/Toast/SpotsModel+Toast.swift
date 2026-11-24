import Foundation

extension SpotsModel {
    public func toast(_ note: ToastNote, of spot: String = "") {
        toasts.add(note, spot: spot, press: press(fixing: note, of: spot), fixKey: note.fix == nil ? nil : config.fixKey)
        host.toast(note, of: spot)
    }

    private func press(fixing note: ToastNote, of spot: String) -> @MainActor @Sendable () -> Void {
        switch note.fix {
        case .url(let url): { [weak self] in self?.host.open(url) }
        case .settings: { [weak self] in
            self?.host.show()
            self?.openSettings()
        }
        case nil: { [weak self] in self?.press(note, of: spot) }
        }
    }

    public func press(_ note: ToastNote, of spot: String) {
        guard !spot.isEmpty else { return }
        if let action = note.action {
            runs.sheets[spot]?.trigger(Message(action), key: ToastNote.head)
        } else {
            _ = open(spot)
        }
    }
}
