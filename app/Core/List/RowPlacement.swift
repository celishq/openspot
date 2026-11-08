import CoreGraphics
import Foundation

/// Where each slot of a row lies in the place of that row. A column whose slots all keep their own size, such as a
/// picture, a switch or a round button, is as wide as they are; the other columns share the rest. The lines share the
/// height evenly, and the app owns each gap.
public struct RowPlacement: Equatable, Sendable {
    public static let gap: CGFloat = 8
    private static let switchWidth: CGFloat = 40
    private static let keyWidth: CGFloat = 84

    public let frames: [String: CGRect]

    public init(drawing: [[String]], parts: [SpotPart], size: CGSize) {
        let columns = max(drawing.map(\.count).max() ?? 1, 1)
        let lines = max(drawing.count, 1)
        let lineGap: CGFloat = lines > 2 ? Self.gap : 0
        let lineHeight = (size.height - lineGap * CGFloat(lines - 1)) / CGFloat(lines)
        var areas: [String: SheetArea] = [:]
        for (y, line) in drawing.enumerated() {
            for (x, word) in line.enumerated() where word != SheetLayout.empty {
                let cell = SheetArea(x0: x, x1: x, y0: y, y1: y)
                areas[word] = areas[word]?.joined(cell) ?? cell
            }
        }
        let byID = Dictionary(parts.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        var fixed: [Int: CGFloat] = [:]
        var flexible = Set<Int>()
        for (id, area) in areas {
            let width = byID[id].flatMap { Self.ownWidth(of: $0, height: CGFloat(area.y1 - area.y0 + 1) * lineHeight) }
            for x in area.x0...area.x1 {
                if let width, area.x0 == area.x1 {
                    fixed[x] = max(fixed[x] ?? 0, width)
                } else {
                    flexible.insert(x)
                }
            }
        }
        for x in 0..<columns where !areas.values.contains(where: { $0.x0 <= x && x <= $0.x1 }) { flexible.insert(x) }
        let fixedColumns = (0..<columns).filter { !flexible.contains($0) && fixed[$0] != nil }
        let shared = size.width - Self.gap * CGFloat(columns - 1) - fixedColumns.reduce(0) { $0 + (fixed[$1] ?? 0) }
        let flexibleCount = columns - fixedColumns.count
        let share: CGFloat = flexibleCount > 0 ? max(shared, 0) / CGFloat(flexibleCount) : 0
        let widths: [CGFloat] = (0..<columns).map { fixedColumns.contains($0) ? fixed[$0] ?? 0 : share }
        var starts: [CGFloat] = []
        var x: CGFloat = 0
        for width in widths {
            starts.append(x)
            x += width + Self.gap
        }
        frames = areas.mapValues { area in
            let left: CGFloat = starts[area.x0]
            let right: CGFloat = starts[area.x1] + widths[area.x1]
            let top: CGFloat = CGFloat(area.y0) * (lineHeight + lineGap)
            let span = CGFloat(area.y1 - area.y0)
            return CGRect(x: left, y: top, width: right - left, height: (span + 1) * lineHeight + span * lineGap)
        }
    }

    /// The width of a slot that keeps its own size, or nil for one that takes what its column gets.
    private static func ownWidth(of part: SpotPart, height: CGFloat) -> CGFloat? {
        switch part.control {
        case .toggle: return switchWidth
        case .shortcut: return keyWidth
        case .none where part.kind == "picture": return height
        case .none:
            if case .symbol = part.press { return height }
            return nil
        default: return nil
        }
    }
}
