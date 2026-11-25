import Foundation

public struct ShelfLayout: Equatable, Sendable {
    public let columns: Int
    public let left: CGFloat
    public let right: CGFloat
    public let band: ClosedRange<CGFloat>
    public let sizes: [SpotSize]
    public let rects: [CGRect]
    public let height: CGFloat

    public init(screen: CGSize, panel: CGRect, sizes wanted: [SpotSize]) {
        let margin = SpotTokens.arrangeMargin
        let room = min(panel.minX, screen.width - panel.maxX) - 2 * margin
        let columns = max(Int(((room + SpotTokens.columnGap) / (SpotTokens.cell + SpotTokens.columnGap)).rounded(.down)), 1)
        let left = margin
        let right = screen.width - margin - SpotTokens.width(columns: columns)
        let sizes = wanted.map { Self.fitted($0, columns: columns) }
        var rects = Array(repeating: CGRect.zero, count: sizes.count)
        for (side, x) in [left, right].enumerated() {
            let indices = sizes.indices.filter { $0 % 2 == side }
            let placements = GridLayout(columns: columns).list(indices.map { sizes[$0] })
            for placement in placements {
                rects[indices[placement.index]] = placement.rect.offsetBy(dx: x, dy: SpotTokens.rowGap)
            }
        }
        self.columns = columns
        self.left = left
        self.right = right
        self.sizes = sizes
        self.rects = rects
        height = (rects.map(\.maxY).max() ?? 0) + SpotTokens.rowGap
        band = SpotTokens.arrangeBar...max(screen.height - SpotTokens.arrangeFoot, SpotTokens.arrangeBar)
    }

    private static func fitted(_ size: SpotSize, columns: Int) -> SpotSize {
        guard size.columns > columns else { return size }
        return SpotSize.all
            .filter { $0.columns <= columns && $0.rows <= size.rows }
            .max { ($0.columns * $0.rows, $0.columns) < ($1.columns * $1.rows, $1.columns) } ?? .small
    }
}
