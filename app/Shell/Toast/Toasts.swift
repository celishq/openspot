import Observation
import OpenspotCore

@MainActor
@Observable
final class Toasts {
    var shown: [Toast] = []
    private(set) var lead: ToastKind?
    @ObservationIgnored var hover: (Bool) -> Void = { _ in }

    func takeLead() {
        let next = shown.first { $0.isShown }?.kind
        if next != lead { lead = next }
    }
}
