import OpenspotCore
import SwiftUI

struct SpotResizeHandle: View {
    let size: SpotSize
    @MainActor private static var rims: [Rim: Path] = [:]
    private static let rimLimit = 32

    var body: some View {
        Self.rim(of: size)
            .stroke(SpotTheme.ink, style: StrokeStyle(lineWidth: SpotTokens.resizeHandleLine, lineCap: .round))
            .frame(width: SpotTokens.resizeHandle, height: SpotTokens.resizeHandle)
            .allowsHitTesting(false)
    }

    private static func rim(of size: SpotSize) -> Path {
        let shape = SurfaceEdge(card: size, mark: .resize)
        let radius = shape.radius
        let card = CGRect(x: 0, y: 0, width: SpotTokens.width(columns: size.columns), height: SpotTokens.height(rows: size.rows))
        let name = Rim(size: card.size, radius: radius)
        if let rim = rims[name] { return rim }
        let edge = SpotRoundShape(shape).path(in: card)
        let centre = CGPoint(x: card.maxX - radius, y: card.maxY - radius)
        let steps = 720
        let corner = (0...steps).map { Double($0) / Double(steps) }.filter { share in
            let point = edge.trimmedPath(from: 0, to: share).currentPoint ?? .zero
            let angle = atan2(point.y - centre.y, point.x - centre.x) * 180 / .pi
            return point.x >= centre.x && point.y >= centre.y && (12...78).contains(angle)
        }
        let side = SpotTokens.resizeHandle
        let rim = edge.trimmedPath(from: corner.first ?? 0, to: corner.last ?? 0)
            .offsetBy(dx: side - card.width, dy: side - card.height)
        if rims.count >= rimLimit { rims = [:] }
        rims[name] = rim
        return rim
    }
}

private struct Rim: Hashable {
    let width: CGFloat
    let height: CGFloat
    let radius: CGFloat

    init(size: CGSize, radius: CGFloat) {
        width = size.width
        height = size.height
        self.radius = radius
    }
}
