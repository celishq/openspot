import Foundation

public struct ShelfLayout: Equatable, Sendable {
    public struct Column: Equatable, Sendable {
        public let x: CGFloat
        public let columns: Int

        public var width: CGFloat {
            SpotTokens.width(columns: columns)
        }
    }

    public let panel: CGRect
    public let band: ClosedRange<CGFloat>
    public let sizes: [SpotSize]
    public let rects: [CGRect]
    public let slots: [ShelfSlot]
    public let height: CGFloat
    public let chunks: [[Int]]
    private let columns: [Column]
    private let top: CGFloat

    public static var chunkPitch: CGFloat {
        SpotTokens.height(rows: 2) + SpotTokens.rowGap
    }

    public subscript(side: ShelfSide) -> Column {
        columns[side.rawValue]
    }

    public init(screen: CGSize, panel: CGRect, sizes wanted: [SpotSize], slots held: [ShelfSlot?] = [], first: Int? = nil) {
        let margin = SpotTokens.arrangeMargin
        let fit = { (room: CGFloat) in max(Int(((room - 2 * margin + SpotTokens.columnGap) / (SpotTokens.cell + SpotTokens.columnGap)).rounded(.down)), 1) }
        let left = fit(panel.minX)
        let columns = [
            Column(x: panel.minX - margin - SpotTokens.width(columns: left), columns: left),
            Column(x: panel.maxX + margin, columns: fit(screen.width - panel.maxX)),
        ]
        let slot = { (index: Int) in held.indices.contains(index) ? held[index] : nil }
        var load = [0, 0]
        var members: [[Int]] = [[], []]
        var sizes = wanted
        let join = { (index: Int, side: ShelfSide) in
            let fitted = Self.fitted(wanted[index], columns: columns[side.rawValue].columns)
            sizes[index] = fitted
            members[side.rawValue].append(index)
            load[side.rawValue] += fitted.columns * fitted.rows
        }
        for index in wanted.indices { if let side = slot(index)?.side { join(index, side) } }
        for index in wanted.indices where slot(index) == nil {
            join(index, load[0] * columns[1].columns <= load[1] * columns[0].columns ? .left : .right)
        }
        let fade = SpotTokens.scrollFadeLength
        band = max(SpotTokens.arrangeBar - fade, 0)...max(min(screen.height - SpotTokens.arrangeFoot + fade, screen.height), SpotTokens.arrangeBar)
        let top = max(panel.minY - band.lowerBound - fade, SpotTokens.rowGap)
        var rects = Array(repeating: CGRect.zero, count: sizes.count)
        var slots = Array(repeating: ShelfSlot(side: .left, cell: GridCell(row: 0, column: 0)), count: sizes.count)
        for side in ShelfSide.allCases {
            let column = columns[side.rawValue]
            let indices = members[side.rawValue]
            let end = indices.filter { $0 != first }.compactMap { index in slot(index).map { $0.cell.row + sizes[index].rows } }.max() ?? 0
            let spots = indices.map { index in
                let cell = slot(index)?.cell ?? GridCell(row: end, column: 0)
                return GridSpot(size: sizes[index], cell: GridCell(row: min(cell.row, end), column: cell.column))
            }
            let grid = GridLayout(columns: column.columns, rows: end + indices.reduce(0) { $0 + sizes[$1].rows })
            for placement in grid.place(spots, first: indices.firstIndex { $0 == first }) {
                let index = indices[placement.index]
                rects[index] = placement.rect.offsetBy(dx: column.x, dy: top)
                slots[index] = ShelfSlot(side: side, cell: placement.cell)
            }
        }
        self.panel = panel
        self.columns = columns
        self.top = top
        self.sizes = sizes
        self.rects = rects
        self.slots = slots
        height = (rects.map(\.maxY).max() ?? 0) + SpotTokens.rowGap
        let count = max(Int((height / Self.chunkPitch).rounded(.up)), 1)
        chunks = (0..<count).map { chunk in rects.indices.filter { Int(rects[$0].minY / Self.chunkPitch) == chunk } }
    }

    public func slot(near corner: CGPoint, size: SpotSize) -> ShelfSlot? {
        let side: ShelfSide = corner.x + SpotTokens.width(columns: size.columns) / 2 < panel.midX ? .left : .right
        let column = self[side]
        let fitted = Self.fitted(size, columns: column.columns)
        let middle = corner.x + SpotTokens.width(columns: fitted.columns) / 2
        guard middle < panel.minX || middle > panel.maxX else { return nil }
        let grid = GridLayout(columns: column.columns, rows: Int(height / SpotTokens.cell) + fitted.rows + 1)
        return ShelfSlot(side: side, cell: grid.cell(near: CGPoint(x: corner.x - column.x, y: corner.y - top), for: fitted))
    }

    private static func fitted(_ size: SpotSize, columns: Int) -> SpotSize {
        guard size.columns > columns else { return size }
        return SpotSize.all
            .filter { $0.columns <= columns && $0.rows <= size.rows }
            .max { ($0.columns * $0.rows, $0.columns) < ($1.columns * $1.rows, $1.columns) } ?? .small
    }
}
