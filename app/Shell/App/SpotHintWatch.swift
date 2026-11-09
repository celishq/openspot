import SwiftUI

/// Watches the model's hint on its own, so that a change of what the hint reads, such as the selected row, reruns only this
/// view and reaches the hint line only when the words change.
struct SpotHintWatch: View {
    let model: SpotsModel
    let take: (String) -> Void

    var body: some View {
        Color.clear
            .onChange(of: model.hint, initial: true) { _, hint in take(hint) }
            .allowsHitTesting(false)
    }
}
