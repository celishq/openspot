import Observation
import OpenspotCore

/// The message a toast shows.
@MainActor
@Observable
final class Toast {
    var message = ""
    var kind = ToastKind.confirm
    var open: (@MainActor @Sendable () -> Void)?
    var isShown = false
}
