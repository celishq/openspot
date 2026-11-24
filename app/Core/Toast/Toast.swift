import CoreGraphics
import Foundation
import Observation

@MainActor
@Observable
public final class Toast: Identifiable {
    public let id: Int
    public let spot: String
    public internal(set) var note: ToastNote
    public internal(set) var words: String
    public internal(set) var kind: ToastKind
    public internal(set) var isShown = false
    @ObservationIgnored public internal(set) var size = CGSize.zero
    @ObservationIgnored var duration: TimeInterval?
    @ObservationIgnored var press: (@MainActor @Sendable () -> Void)?
    @ObservationIgnored var fixKey: Shortcut?

    public init(id: Int, spot: String = "", note: ToastNote, words: String? = nil, kind: ToastKind) {
        self.id = id
        self.spot = spot
        self.note = note
        self.words = words ?? note.words
        self.kind = kind
    }

    func take(_ note: ToastNote, words: String, kind: ToastKind) {
        if note != self.note { self.note = note }
        if words != self.words { self.words = words }
        if kind != self.kind { self.kind = kind }
    }

    public var copy: Toast {
        Toast(id: id, spot: spot, note: note, words: words, kind: kind)
    }
}
