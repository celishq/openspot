import Foundation

extension SpotsModel {
    static let workToast = "work"

    public func toast(_ note: ToastNote, of spot: String = "") {
        toasts.add(note, spot: spot, press: press(fixing: note, of: spot), fixKey: note.fix == nil ? nil : config.fixKey)
        host.toast(note, of: spot)
    }

    private func press(fixing note: ToastNote, of spot: String) -> @MainActor @Sendable () -> Void {
        switch note.fix {
        case .url(let url): { [weak self] in
            if let access = MacAccess(pane: url), self?.openSettings(at: .accessOf(access)) == true { return }
            self?.host.open(url)
        }
        case .schedule(let id): { [weak self] in self?.runs.allowSchedule(of: id) }
        case .settings: { [weak self] in self?.openSettings(at: .general) }
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

    func toastWork(_ works: [Work]) {
        var next: [String: String] = [:]
        for work in works where next[work.spot] == nil { next[work.spot] = work.words }
        for spot in workToasts.keys where next[spot] == nil { toasts.drop(Self.workToast, of: spot) }
        for (spot, words) in next where workToasts[spot] != words {
            toasts.add(.work(words, id: Self.workToast), spot: spot, press: { [weak self] in _ = self?.open(spot) })
        }
        workToasts = next
    }

    func askSchedule(of id: String) {
        let name = runs.sheets[id]?.spot.name ?? id
        toast(ToastNote(words: "\(name) runs by itself on a schedule, so Openspot held its first run. Click to allow it.", fix: .schedule(id)), of: id)
    }
}
