import OpenspotCore
import SwiftUI

struct SpotBackdropEdge: View {
    let edge: BackdropEdge
    let rect: CGRect

    @MainActor private static let drawn = Dictionary(uniqueKeysWithValues: BackdropEdge.blurs.map { ($0, pictures(of: $0)) })

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

    @MainActor private static func pictures(of edge: BackdropEdge) -> [Image] {
        let size = edge.pictureSize
        let renderer = ImageRenderer(content: RoundedRectangle(cornerRadius: edge.corner, style: .continuous)
            .fill(Color.black)
            .padding(edge.inset)
            .frame(width: size.width, height: size.height)
            .blur(radius: edge.softness))
        let whole = renderer.cgImage
        return edge.pieces(in: CGRect(origin: .zero, size: size)).map { piece in
            guard let part = whole?.cropping(to: piece.source) else { return Image(systemName: "square.fill") }
            return Image(decorative: part, scale: 1).resizable().antialiased(false).renderingMode(.template)
        }
    }
}
