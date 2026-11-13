import SwiftUI

/// A slider that keeps its value while the person drags it, and sends it once they let go, so that a tick redraws only it.
struct SpotSlotSlider: View {
    let level: Double
    let range: ClosedRange<Double>
    let onEnd: (Double) -> Void
    @State private var dragged: Double?

    var body: some View {
        Slider(value: Binding(get: { dragged ?? level }, set: { dragged = $0 }), in: range) { editing in
            if !editing, let dragged { onEnd(dragged); self.dragged = nil }
        }
        .controlSize(.small)
        .tint(SpotTheme.ink)
        .labelsHidden()
    }
}
