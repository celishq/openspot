import Observation
import OpenspotCore

@MainActor
@Observable
final class Toast {
    var message = ""
    var kind = ToastKind.confirm
    var open: (@MainActor @Sendable () -> Void)?
    var isShown = false
}
