import Foundation

extension SpotsModel {
    public func toast(_ note: ToastNote, of spot: String = "") {
        host.toast(note, of: spot)
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
