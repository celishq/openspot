import OpenspotCore
import SwiftUI

struct SpotThemeMarkShape: Shape {
    let mark: ThemeMark

    private static let arcSteps = 16

    func path(in rect: CGRect) -> Path {
        var path = Path()
        switch mark.shape {
        case .band:
            path.addRect(mark.rect)
        case .arc(let centre, let radius):
            let start = mark.rect.midX < centre.x ? Double.pi : 0
            let end = mark.rect.midY < centre.y ? -Double.pi / 2 : Double.pi / 2
            let points = (0...Self.arcSteps).map { step in
                let angle = start + (end - start + (start > 0 && end < 0 ? 2 * Double.pi : 0)) * Double(step) / Double(Self.arcSteps)
                return CGPoint(x: centre.x + radius * cos(angle), y: centre.y + radius * sin(angle))
            }
            path.addLines(points)
        }
        return path
    }
}
