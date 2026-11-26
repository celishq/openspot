import Foundation

public struct ShelfLayout: Equatable, Sendable {
    public let leftColumns: Int
    public let rightColumns: Int
    public let left: CGFloat
    public let right: CGFloat
    public let band: ClosedRange<CGFloat>
    public let sizes: [SpotSize]
    public let rects: [CGRect]
    public let height: CGFloat
    public let chunks: [[Int]]

    public static var chunkPitch: CGFloat {
        SpotTokens.height(rows: 2) + SpotTokens.rowGap
    }

    public init(screen: CGSize, panel: CGRect, sizes wanted: [SpotSize]) {
        let margin = SpotTokens.arrangeMargin
        let fit = { (room: CGFloat) in max(Int(((room - 2 * margin + SpotTokens.columnGap) / (SpotTokens.cell + SpotTokens.columnGap)).rounded(.down)), 1) }
        let columns = [fit(panel.minX), fit(screen.width - panel.maxX)]
        let origins = [panel.minX - margin - SpotTokens.width(columns: columns[0]), panel.maxX + margin]
        var load = [0, 0]
        var members: [[Int]] = [[], []]
        var sizes: [SpotSize] = []
        for (index, size) in wanted.enumerated() {
            let side = load[0] * columns[1] <= load[1] * columns[0] ? 0 : 1
            let fitted = Self.fitted(size, columns: columns[side])
            sizes.append(fitted)
            members[side].append(index)
            load[side] += fitted.columns * fitted.rows
        }
        var rects = Array(repeating: CGRect.zero, count: sizes.count)
        for side in 0..<2 {
            let indices = members[side]
            for placement in GridLayout(columns: columns[side]).list(indices.map { sizes[$0] }) {
                rects[indices[placement.index]] = placement.rect.offsetBy(dx: origins[side], dy: SpotTokens.rowGap)
            }
        }
        leftColumns = columns[0]
        rightColumns = columns[1]
        left = origins[0]
        right = origins[1]
        self.sizes = sizes
        self.rects = rects
        height = (rects.map(\.maxY).max() ?? 0) + SpotTokens.rowGap
        let count = max(Int((height / Self.chunkPitch).rounded(.up)), 1)
        chunks = (0..<count).map { chunk in rects.indices.filter { Int(rects[$0].minY / Self.chunkPitch) == chunk } }
        let fade = SpotTokens.scrollFadeLength
        band = max(SpotTokens.arrangeBar - fade, 0)...max(min(screen.height - SpotTokens.arrangeFoot + fade, screen.height), SpotTokens.arrangeBar)
    }

    private static func fitted(_ size: SpotSize, columns: Int) -> SpotSize {
        guard size.columns > columns else { return size }
        return SpotSize.all
            .filter { $0.columns <= columns && $0.rows <= size.rows }
            .max { ($0.columns * $0.rows, $0.columns) < ($1.columns * $1.rows, $1.columns) } ?? .small
    }
}
