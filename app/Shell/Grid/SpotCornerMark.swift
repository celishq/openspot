import OpenspotCore
import SwiftUI

struct SpotCornerMark: View {
    enum Face: Equatable {
        case symbol(String)
        case word(String)
    }

    let face: Face
    let corner: SpotCornerButton.Corner
    let size: SpotSize

    var body: some View {
        let inset = SurfaceEdge(card: size).rim - SpotTokens.cornerMark / 2
        let cap = SpotRoundShape(radius: SpotTokens.cornerMarkRadius)
        label
            .foregroundStyle(SpotTheme.ink)
            .frame(minWidth: SpotTokens.cornerMark, minHeight: SpotTokens.cornerMark, maxHeight: SpotTokens.cornerMark)
            .background(SpotTheme.cornerFill, in: cap)
            .overlay(cap.strokeBorder(SpotTheme.ink.opacity(SpotTheme.track)))
            .offset(x: corner == .leading ? inset : -inset, y: inset)
    }

    @ViewBuilder
    private var label: some View {
        switch face {
        case .symbol(let name):
            Image(systemName: name).font(SpotType.cornerFault)
        case .word(let text):
            Text(text).font(SpotType.cornerMark).padding(.horizontal, SpotTokens.cornerMarkPadding).fixedSize()
        }
    }
}
