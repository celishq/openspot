import OpenspotCore
import SwiftUI

struct SpotBackdropEdge: View, @preconcurrency Animatable {
    struct Look: Hashable, Sendable {
        let inset: CGFloat
        let softness: CGFloat

        var cap: CGFloat {
            (inset + corner + SpotTheme.backdropEdgeReach * softness).rounded(.up)
        }

        var corner: CGFloat {
            SpotTokens.radius + SpotTokens.halo - inset
        }
    }

    let look: Look
    var rect: CGRect

    @MainActor private static var pictures: [Look: Image] = [:]
    private static let middle: CGFloat = 2

    var animatableData: AnimatablePair<CGFloat, AnimatablePair<CGFloat, CGFloat>> {
        get { AnimatablePair(rect.minX, AnimatablePair(rect.width, rect.height)) }
        set { rect = CGRect(x: newValue.first, y: rect.minY, width: newValue.second.first, height: newValue.second.second) }
    }

    var body: some View {
        let cap = look.cap
        Self.picture(of: look)
            .resizable(capInsets: EdgeInsets(top: cap, leading: cap, bottom: cap, trailing: cap), resizingMode: .stretch)
            .frame(width: rect.width, height: rect.height)
            .offset(x: rect.minX, y: rect.minY)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    @MainActor private static func picture(of look: Look) -> Image {
        if let picture = pictures[look] { return picture }
        let side = 2 * look.cap + middle
        let renderer = ImageRenderer(content: RoundedRectangle(cornerRadius: look.corner, style: .continuous)
            .fill(Color.black)
            .padding(look.inset)
            .frame(width: side, height: side)
            .blur(radius: look.softness))
        let picture = renderer.cgImage.map { Image(decorative: $0, scale: 1).renderingMode(.template) } ?? Image(systemName: "square.fill")
        pictures[look] = picture
        return picture
    }
}
