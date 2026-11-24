import OpenspotCore
import SwiftUI

struct SpotContextCover: ViewModifier {
    let model: SpotsModel

    func body(content: Content) -> some View {
        content.opacity(model.contextShape == .wide ? MotionTokens.hiddenOpacity : 1)
    }
}
