import CoreGraphics
import Observation
import OpenspotCore

@MainActor
@Observable
final class Toasts {
    var shown: [Toast] = []
    private(set) var lead: ToastKind?
    private(set) var places: [Int: ToastLayout.Place] = [:]
    @ObservationIgnored var isExpanded = false
    @ObservationIgnored private(set) var height: CGFloat = 0
    @ObservationIgnored var hover: (Bool) -> Void = { _ in }

    func takeLead() {
        let next = shown.first { $0.isShown }?.kind
        if next != lead { lead = next }
    }

    func arrange() {
        let layout = ToastLayout(heights: shown.map(\.size.height), isExpanded: isExpanded)
        let next = Dictionary(uniqueKeysWithValues: zip(shown.map(\.id), layout.places))
        if next != places { places = next }
        height = layout.height
    }
}
