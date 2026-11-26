import Foundation

public struct ShelfLayout: Equatable, Sendable {
    public let panel: CGRect
    public let leftColumns: Int
    public let rightColumns: Int
    public let left: CGFloat
    public let right: CGFloat
    public let band: ClosedRange<CGFloat>
    public let sizes: [SpotSize]
    public let rects: [CGRect]
    public let slots: [ShelfSlot]
    let top: CGFloat
    public let height: CGFloat
    public let chunks: [[Int]]

    public static var chunkPitch: CGFloat {
        SpotTokens.height(rows: 2) + SpotTokens.rowGap
    }

    public init(screen: CGSize, panel: CGRect, sizes wanted: [SpotSize], slots held: [ShelfSlot?] = [], first: Int? = nil) {
        let margin = SpotTokens.arrangeMargin
        let fit = { (room: CGFloat) in max(Int(((room - 2 * margin + SpotTokens.columnGap) / (SpotTokens.cell + SpotTokens.columnGap)).rounded(.down)), 1) }
        let columns = [fit(panel.minX), fit(screen.width - panel.maxX)]
        let origins = [panel.minX - margin - SpotTokens.width(columns: columns[0]), panel.maxX + margin]
        let slot = { (index: Int) in held.indices.contains(index) ? held[index] : nil }
        var load = [0, 0]
        var members: [[Int]] = [[], []]
        var sizes = wanted
        let join = { (index: Int, side: Int) in
            let fitted = Self.fitted(wanted[index], columns: columns[side])
            sizes[index] = fitted
            members[side].append(index)
            load[side] += fitted.columns * fitted.rows
        }
        for index in wanted.indices { if let side = slot(index)?.side { join(index, side) } }
        for index in wanted.indices where slot(index) == nil {
            join(index, load[0] * columns[1] <= load[1] * columns[0] ? 0 : 1)
        }
        let fade = SpotTokens.scrollFadeLength
        band = max(SpotTokens.arrangeBar - fade, 0)...max(min(screen.height - SpotTokens.arrangeFoot + fade, screen.height), SpotTokens.arrangeBar)
        let top = max(panel.minY - band.lowerBound - fade, SpotTokens.rowGap)
        var rects = Array(repeating: CGRect.zero, count: sizes.count)
        var slots = Array(repeating: ShelfSlot(side: 0, cell: GridCell(row: 0, column: 0)), count: sizes.count)
        for side in 0..<2 {
            let indices = members[side]
            let end = indices.filter { $0 != first }.compactMap { index in slot(index).map { $0.cell.row + sizes[index].rows } }.max() ?? 0
            let spots = indices.map { index in
                let cell = slot(index)?.cell ?? GridCell(row: end, column: 0)
                return GridSpot(size: sizes[index], cell: GridCell(row: min(cell.row, end), column: cell.column))
            }
            let grid = GridLayout(columns: columns[side], rows: end + indices.reduce(0) { $0 + sizes[$1].rows })
            for placement in grid.place(spots, first: indices.firstIndex { $0 == first }) {
                let index = indices[placement.index]
                rects[index] = placement.rect.offsetBy(dx: origins[side], dy: top)
                slots[index] = ShelfSlot(side: side, cell: placement.cell)
            }
        }
        self.panel = panel
        leftColumns = columns[0]
        rightColumns = columns[1]
        left = origins[0]
        right = origins[1]
        self.sizes = sizes
        self.rects = rects
        self.slots = slots
        self.top = top
        height = (rects.map(\.maxY).max() ?? 0) + SpotTokens.rowGap
        let count = max(Int((height / Self.chunkPitch).rounded(.up)), 1)
        chunks = (0..<count).map { chunk in rects.indices.filter { Int(rects[$0].minY / Self.chunkPitch) == chunk } }
    }

    public func slot(near corner: CGPoint, size: SpotSize) -> ShelfSlot? {
        let columns = [leftColumns, rightColumns]
        let side = corner.x + SpotTokens.width(columns: size.columns) / 2 < panel.midX ? 0 : 1
        let fitted = Self.fitted(size, columns: columns[side])
        let middle = corner.x + SpotTokens.width(columns: fitted.columns) / 2
        guard middle < panel.minX || middle > panel.maxX else { return nil }
        let grid = GridLayout(columns: columns[side], rows: Int(height / SpotTokens.cell) + fitted.rows + 1)
        return ShelfSlot(side: side, cell: grid.cell(near: CGPoint(x: corner.x - [left, right][side], y: corner.y - top), for: fitted))
    }

    private static func fitted(_ size: SpotSize, columns: Int) -> SpotSize {
        guard size.columns > columns else { return size }
        return SpotSize.all
            .filter { $0.columns <= columns && $0.rows <= size.rows }
            .max { ($0.columns * $0.rows, $0.columns) < ($1.columns * $1.rows, $1.columns) } ?? .small
    }
}
