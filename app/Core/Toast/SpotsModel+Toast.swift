import Foundation

extension SpotsModel {
    public func toast(_ note: ToastNote, of spot: String = "") {
        toasts.add(note, spot: spot, press: press(fixing: note, of: spot), fixKey: note.fix == nil ? nil : config.fixKey)
        host.toast(note, of: spot)
    }

    private func press(fixing note: ToastNote, of spot: String) -> @MainActor @Sendable () -> Void {
        switch note.fix {
        case .url(let url): { [weak self] in
            if let access = MacAccess(pane: url), self?.openSettings(at: "access/\(access.rawValue)") == true { return }
            self?.host.open(url)
        }
        case .settings: { [weak self] in self?.openSettings(at: "keys") }
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
