import Foundation

/// A resize of the panel by its corner in Edit Spots: the sizes it may take, with four columns or more in steps of four and
/// from the rows that its cards need up to a limit, and the size whose corner lies nearest the pointer.
public struct PanelResize: Sendable {
    public let start: PanelSize
    private let choices: [PanelSize]

    public init(start: PanelSize, sizes: [SpotSize], limit: PanelSize) {
        self.start = start
        choices = PanelSize.columnSteps.filter { $0 <= max(limit.columns, SpotTokens.columns) }.flatMap { columns in
            let needed = max(SpotGrid(columns: columns).place(sizes).map { $0.row + $0.size.rows }.max() ?? 0, 1)
            return (needed...max(needed, limit.rows)).map { PanelSize(columns: columns, rows: $0) }
        }
    }

    /// The bottom right corner of the grid when the pointer has moved this far from where the resize started.
    public func corner(movedBy translation: CGSize) -> CGPoint {
        CGPoint(x: SpotTokens.width(columns: start.columns) + translation.width, y: SpotTokens.height(rows: start.rows) + translation.height)
    }

    /// The size whose bottom right corner lies nearest to this point.
    public func nearest(to point: CGPoint) -> PanelSize {
        choices.min { distance(from: point, to: $0) < distance(from: point, to: $1) } ?? start
    }

    private func distance(from point: CGPoint, to size: PanelSize) -> CGFloat {
        hypot(SpotTokens.width(columns: size.columns) - point.x, SpotTokens.height(rows: size.rows) - point.y)
    }
}
