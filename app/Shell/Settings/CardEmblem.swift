import OpenspotCore
import SwiftUI

struct CardEmblem: Shape {
    let dots: [CGRect]

    func path(in rect: CGRect) -> Path {
        let scale = rect.width / SpotTokens.emblemSide
        var path = Path()
        for dot in dots {
            path.addEllipse(in: CGRect(x: rect.minX + dot.minX * scale, y: rect.minY + dot.minY * scale, width: dot.width * scale, height: dot.height * scale))
        }
        return path
    }
}
