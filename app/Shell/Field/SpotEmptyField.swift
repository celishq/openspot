import OpenspotCore
import SwiftUI

struct SpotEmptyField: ViewModifier {
    let model: SpotsModel
    let isHidden: Bool

    func body(content: Content) -> some View {
        content.opacity(model.searchText.isEmpty && !isHidden ? 1 : 0)
    }
}
