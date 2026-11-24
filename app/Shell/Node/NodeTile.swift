import OpenspotCore
import SwiftUI

struct NodeTile: ViewModifier {
    @Environment(\.spotSurfaceEdge) private var surface
    let isOn: Bool

    func body(content: Content) -> some View {
        if isOn {
            content
                .padding(.horizontal, SpotTokens.padding)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(SpotTheme.ink.opacity(SpotTheme.fill), in: SpotRoundShape(surface.inner()))
        } else {
            content
        }
    }
}
