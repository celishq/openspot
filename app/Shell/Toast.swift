import Observation
import OpenspotCore

/// The message a toast shows.
@MainActor
@Observable
final class Toast {
    var message = ""
    var symbol: String?
    /// The key that opens the fix of a failure, while it is held.
    var key: Shortcut?
    var open: (() -> Void)?
    var isShown = false
}
