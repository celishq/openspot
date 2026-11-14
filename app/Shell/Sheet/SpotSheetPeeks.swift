import OpenspotCore
import SwiftUI

/// The marks beside the open sheet of the sheets that wait in the history: one on the left while a sheet lies behind, and
/// one on the right while a sheet lies ahead. A click on a mark goes there. It alone reads the history.
struct SpotSheetPeeks: View {
    let model: SpotsModel
    let rect: CGRect

    var body: some View {
        ZStack(alignment: .topLeading) {
            if model.history.behind != nil {
                mark(x: rect.minX - SpotTokens.peekGap - SpotTokens.peekWidth) { model.goBack() }
            }
            if model.history.ahead != nil {
                mark(x: rect.maxX + SpotTokens.peekGap) { model.goForward() }
            }
        }
    }

    private func mark(x: CGFloat, go: @escaping () -> Void) -> some View {
        let height = max(rect.height - 2 * SpotTokens.radius, SpotTokens.peekWidth)
        return Color.clear
            .frame(width: SpotTokens.peekWidth, height: height)
            .modifier(SpotGlass(radius: SpotTokens.peekWidth / 2))
            .padding(.horizontal, SpotTokens.peekGap)
            .contentShape(Rectangle())
            .onTapGesture(perform: go)
            .offset(x: x - SpotTokens.peekGap, y: rect.midY - height / 2)
    }
}
