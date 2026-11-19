import CoreGraphics
import Foundation

public struct CardLayout: Equatable, Sendable {
    public let size: SpotSize
    public let columns: Int
    public let rows: Int
    public let names: [String]
    public let slots: [SheetArea]

    public init(drawing: [String], size: SpotSize? = nil) {
        let cells = drawing.map(Self.words)
        var names: [String] = []
        var areas: [String: SheetArea] = [:]
        for (y, line) in cells.enumerated() {
            for (x, name) in line.enumerated() where name != SheetLayout.empty {
                let area = SheetArea(x0: x, x1: x, y0: y, y1: y)
                if areas[name] == nil { names.append(name) }
                areas[name] = areas[name]?.joined(area) ?? area
            }
        }
        self.size = size ?? (drawing.count == 1 ? .strip : .large)
        columns = max(cells.map(\.count).max() ?? 1, 1)
        rows = max(cells.count, 1)
        self.names = names
        slots = names.compactMap { areas[$0] }
    }

    public func rect(of slot: SheetArea, in room: CGSize, gap: CGFloat, sideGap: CGFloat) -> CGRect {
        let middle = columns > 1 && columns.isMultiple(of: 2) ? columns / 2 : nil
        let extra = middle == nil ? 0 : sideGap - gap
        let cellWidth = (room.width - CGFloat(columns - 1) * gap - extra) / CGFloat(columns)
        let cellHeight = (room.height - CGFloat(rows - 1) * gap) / CGFloat(rows)
        let x = { (column: Int) in
            CGFloat(column) * (cellWidth + gap) + (middle.map { column >= $0 } == true ? extra : 0)
        }
        let y = { (row: Int) in CGFloat(row) * (cellHeight + gap) }
        return CGRect(
            x: x(slot.x0),
            y: y(slot.y0),
            width: x(slot.x1) + cellWidth - x(slot.x0),
            height: y(slot.y1) + cellHeight - y(slot.y0)
        )
    }

    private static func words(_ line: String) -> [String] {
        line.split(whereSeparator: \.isWhitespace).map(String.init)
    }
}
