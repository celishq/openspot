import CoreGraphics
import Foundation
import Observation

@MainActor
@Observable
public final class Toast: Identifiable {
    public let id: ToastID
    public internal(set) var note: ToastNote
    public internal(set) var words: String
    @ObservationIgnored public internal(set) var size = CGSize.zero
    @ObservationIgnored var duration: TimeInterval?
    @ObservationIgnored var press: (@MainActor @Sendable () -> Void)?
    @ObservationIgnored var fixKey: Shortcut?

    public init(id: ToastID, note: ToastNote, words: String? = nil) {
        self.id = id
        self.note = note
        self.words = words ?? note.words
    }

    func take(_ note: ToastNote, words: String) {
        if note != self.note { self.note = note }
        if words != self.words { self.words = words }
    }

    public var copy: Toast {
        Toast(id: id, note: note, words: words)
    }
}
