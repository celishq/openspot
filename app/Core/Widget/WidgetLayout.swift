import CoreGraphics
import Foundation

public struct WidgetLayout: Equatable, Sendable {
    public enum Form: Equatable, Sendable {
        case big
        case line
        case half
        case stat
        case control
    }

    public let name: String
    public let size: SpotSize
    public let columns: Int
    public let rows: Int
    public let names: [String]
    public let slots: [SheetArea]

    public init(drawing: [String], size: SpotSize? = nil) {
        self.init(name: "grid", size: size ?? (drawing.count == 1 ? .strip : .large), drawing: drawing)
    }

    private init(name: String, size: SpotSize, drawing: [String]) {
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
        self.name = name
        self.size = size
        columns = max(cells.map(\.count).max() ?? 1, 1)
        rows = max(cells.count, 1)
        self.names = names
        slots = names.compactMap { areas[$0] }
    }

    public static func faults(in drawing: [String]) -> [String] {
        let cells = drawing.map(words)
        guard !cells.isEmpty else { return ["its grid is empty"] }
        var faults: [String] = []
        if Set(cells.map(\.count)).count > 1 { faults.append("each grid line needs the same number of columns") }
        if cells.contains(where: { $0.contains(SheetLayout.divider) }) { faults.append("a widget's grid cannot have a divider") }
        let layout = WidgetLayout(drawing: drawing)
        for (name, area) in zip(layout.names, layout.slots) where name != SheetLayout.divider {
            let count = cells.reduce(0) { $0 + $1.filter { $0 == name }.count }
            if count != area.size { faults.append("the metric \(name) is not a rectangle") }
        }
        return faults
    }

    public func form(of slot: SheetArea, on card: SpotSize) -> Form {
        if card == .small { return .control }
        let wide = Double(slot.x1 - slot.x0 + 1) / Double(columns) * Double(card.columns)
        let tall = Double(slot.y1 - slot.y0 + 1) / Double(rows) * Double(card.rows)
        if wide >= 2, tall >= 2 { return .big }
        if wide <= 1 { return .stat }
        return tall < 1 ? .line : .half
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
