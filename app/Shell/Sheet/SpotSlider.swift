import OpenspotCore
import SwiftUI

struct SpotSlider: View {
    let level: Double
    let range: ClosedRange<Double>
    var words: String?
    let onEnd: (Double) -> Void
    @State private var dragged: Double?

    var body: some View {
        HStack(spacing: SpotTokens.padding) {
            Slider(value: Binding(get: { dragged ?? level }, set: { dragged = $0 }), in: range) { editing in
                if !editing, let dragged { onEnd(dragged); self.dragged = nil }
            }
            .controlSize(.small)
            .tint(SpotTheme.highlight)
            .labelsHidden()
            if let words {
                Text(dragged.map { String(Int($0.rounded())) } ?? words)
                    .font(SpotType.detail)
                    .monospacedDigit()
                    .modifier(SpotSecondaryText())
            }
        }
    }
}
