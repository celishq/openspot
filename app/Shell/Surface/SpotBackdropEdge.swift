import OpenspotCore
import SwiftUI

struct SpotBackdropEdge: View {
    let edge: BackdropEdge
    let rect: CGRect

    @MainActor private(set) static var parts = drawParts()
    @MainActor private static var drawn = pictures(of: parts)

    @MainActor static func draw() {
        parts = drawParts()
        drawn = pictures(of: parts)
    }

    var body: some View {
        let pictures = Self.drawn[edge] ?? []
        ZStack(alignment: .topLeading) {
            ForEach(Array(edge.pieces(in: rect).enumerated()), id: \.offset) { index, piece in
                pictures[index]
                    .frame(width: piece.source.width, height: piece.source.height)
                    .scaleEffect(x: piece.scale.width, y: piece.scale.height, anchor: .topLeading)
                    .offset(x: piece.origin.x, y: piece.origin.y)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    @MainActor private static func drawParts() -> [BackdropEdge: [CGImage?]] {
        Dictionary(uniqueKeysWithValues: BackdropEdge.blurs.map { ($0, drawParts(of: $0)) })
    }

    @MainActor private static func drawParts(of edge: BackdropEdge) -> [CGImage?] {
        let size = edge.pictureSize
        let renderer = ImageRenderer(content: RoundedRectangle(cornerRadius: edge.corner, style: .continuous)
            .fill(SpotTheme.mask)
            .padding(edge.inset)
            .frame(width: size.width, height: size.height)
            .blur(radius: edge.softness))
        let whole = renderer.cgImage
        return edge.pieces(in: CGRect(origin: .zero, size: size)).map { whole?.cropping(to: $0.source) }
    }

    @MainActor private static func pictures(of parts: [BackdropEdge: [CGImage?]]) -> [BackdropEdge: [Image]] {
        parts.mapValues { edge in
            edge.map { part in
                guard let part else { return Image(systemName: "square.fill") }
                return Image(decorative: part, scale: 1).resizable().antialiased(false).renderingMode(.template)
            }
        }
    }
}
