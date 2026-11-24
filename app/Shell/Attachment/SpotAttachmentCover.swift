import OpenspotCore
import SwiftUI

struct SpotAttachmentCover: ViewModifier {
    let model: SpotsModel

    func body(content: Content) -> some View {
        content.opacity(model.isFieldCovered ? MotionTokens.hiddenOpacity : 1)
    }
}
