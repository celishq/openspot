import OpenspotCore
import SwiftUI

struct SpotShine<Content: View>: View {
    let content: Content
    @State private var band: CGFloat = -0.5

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .mask {
                LinearGradient(
                    stops: [
                        .init(color: .black.opacity(SpotTheme.shineDim), location: 0),
                        .init(color: .black, location: 0.5),
                        .init(color: .black.opacity(SpotTheme.shineDim), location: 1),
                    ],
                    startPoint: UnitPoint(x: band - 0.5, y: 0.5),
                    endPoint: UnitPoint(x: band + 0.5, y: 0.5)
                )
            }
            .task { withAnimation(SpotMotion.shine) { band = 1.5 } }
    }
}

extension SpotShine where Content == Text {
    init(words: String, font: Font) {
        self.init { Text(words).font(font) }
    }
}
