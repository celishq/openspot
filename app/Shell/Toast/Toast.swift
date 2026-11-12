import Observation

/// The message a toast shows.
@MainActor
@Observable
final class Toast {
    var message = ""
    var symbol: String?
    var open: (@MainActor @Sendable () -> Void)?
    var isShown = false
}
