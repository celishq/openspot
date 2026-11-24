import Foundation
import Observation
import OpenspotCore

@MainActor
@Observable
final class Toast: Identifiable {
    let id: Int
    var message: String
    var kind: ToastKind
    var tree: ViewTree?
    @ObservationIgnored var duration: TimeInterval?
    @ObservationIgnored var open: (@MainActor @Sendable () -> Void)?
    @ObservationIgnored var fixKey: Shortcut?
    var isShown = false

    init(id: Int, message: String, kind: ToastKind, tree: ViewTree? = nil, duration: TimeInterval?) {
        self.id = id
        self.tree = tree
        self.message = message
        self.kind = kind
        self.duration = duration
    }
}
