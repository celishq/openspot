import OpenspotCore
import SwiftUI

struct SpotContextCover: ViewModifier {
    let model: SpotsModel

    func body(content: Content) -> some View {
        content.opacity(model.isContextWide ? MotionTokens.hiddenOpacity : 1)
    }
}
