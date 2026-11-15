import OpenspotCore
import SwiftUI

struct SpotFieldShade: View {
    let model: SpotsModel

    var body: some View {
        let shade = model.gridShade
        if shade.coversField {
            SpotRoundShape(SurfaceEdge(card: .strip))
                .fill(SpotTheme.dim)
                .frame(width: SpotFieldView.rect.width, height: SpotFieldView.rect.height)
                .offset(x: SpotFieldView.rect.minX, y: SpotFieldView.rect.minY)
                .opacity(shade.isOn ? 1 : MotionTokens.hiddenOpacity)
                .allowsHitTesting(false)
        }
    }
}
