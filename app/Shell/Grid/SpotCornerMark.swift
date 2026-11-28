import OpenspotCore
import SwiftUI

struct SpotCornerMark: View {
    let symbol: String
    let size: SpotSize

    var body: some View {
        let inset = SurfaceEdge(card: size).rim - SpotTokens.cornerMark / 2
        let cap = SpotRoundShape(radius: SpotTokens.cornerMarkRadius)
        Image(systemName: symbol)
            .font(SpotType.cornerFault)
            .foregroundStyle(SpotTheme.ink)
            .frame(width: SpotTokens.cornerMark, height: SpotTokens.cornerMark)
            .background(SpotTheme.cornerFill, in: cap)
            .overlay(cap.strokeBorder(SpotTheme.ink.opacity(SpotTheme.track)))
            .offset(x: -inset, y: inset)
    }
}
