import OpenspotCore
import SwiftUI

/// Shows its content only while the search is empty. It reads the search itself, so that typing reruns only this modifier.
struct SpotEmptyField: ViewModifier {
    let model: SpotsModel
    let isHidden: Bool

    func body(content: Content) -> some View {
        content.opacity(model.searchText.isEmpty && !isHidden ? 1 : 0)
    }
}
