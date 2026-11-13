import Foundation
import CoreGraphics

/// Where each part of a sheet lies, in points. The app sets one gap, one row height and each centre here, so a script
/// has no way to make an uneven sheet.
public struct SheetPlacement: Equatable, Sendable {
    public enum Side: Equatable, Sendable {
        case fill, start, center, end
    }

    /// The place of one part.
    public struct Frame: Equatable, Sendable {
        public let rect: CGRect
        public let isOnTop: Bool
        public let horizontal: Side
        public let vertical: Side
        public let roundSize: CGFloat
        public let clearTop: CGFloat
        public let clearBottom: CGFloat

        /// Whether it covers two lines or more, where a text shows its detail under its title.
        public var hasDetailUnderTitle: Bool {
            rect.height >= SheetPlacement.rowHeight * 2
        }
    }

    public static let width: CGFloat = 263
    public static let maxHeight: CGFloat = 442
    public static let gap: CGFloat = 6
    public static let rowHeight: CGFloat = 40
    public static let maxRound: CGFloat = 44
    public static let dividerHeight: CGFloat = 1
    /// The height of the search field over a sheet that repeats rows, with its gap.
    public static let fieldRoom: CGFloat = 54
    /// How far text moves from a round button that sits on the divider at its edge.
    private static let seamClearance: CGFloat = 22

    public let frames: [String: Frame]
    public let lines: [CGRect]
    public let height: CGFloat
    /// Where the rows of the script flow.
    public let repeatFrame: CGRect?

    /// Whether the content is taller than the panel, so that it scrolls.
    public var overflows: Bool {
        height > Self.maxHeight - (repeatFrame == nil ? 0 : Self.fieldRoom)
    }

    public init(parts: [SpotPart], layout: SheetLayout) {
        let rows = layout.rows
        let gap = Self.gap
        let columns = max(rows.map(\.count).max() ?? 1, 1)
        let cell = (Self.width - gap * CGFloat(columns - 1)) / CGFloat(columns)
        let columnX = { (x: Int) in CGFloat(x) * (cell + gap) }

        var heights = rows.indices.map { layout.hasDivider(inRow: $0) ? Self.dividerHeight : Self.rowHeight }
        var fillRows = Set<Int>()
        for part in parts {
            guard let letter = layout.letter(of: part), let area = layout.areas[letter] else { continue }
            guard part.growsRow else { continue }
            for y in area.y0...area.y1 where !layout.hasDivider(inRow: y) { fillRows.insert(y) }
        }
        let repeatArea = layout.repeated.flatMap { layout.areas[$0.area] }
        if let repeatArea {
            for y in repeatArea.y0...repeatArea.y1 where !layout.hasDivider(inRow: y) { fillRows.insert(y) }
        }
        let gaps = gap * CGFloat(max(rows.count - 1, 0))
        if !fillRows.isEmpty {
            let room = Self.maxHeight - (repeatArea == nil ? 0 : Self.fieldRoom)
            let free = room - heights.reduce(0, +) - gaps
            if free > 0 { for y in fillRows { heights[y] += free / CGFloat(fillRows.count) } }
        }

        var rowY: [CGFloat] = []
        var y: CGFloat = 0
        for row in heights {
            rowY.append(y)
            y += row + gap
        }
        let rect = { (area: SheetArea) in
            CGRect(
                x: columnX(area.x0),
                y: rowY[area.y0],
                width: columnX(area.x1) + cell - columnX(area.x0),
                height: rowY[area.y1] + heights[area.y1] - rowY[area.y0]
            )
        }

        let placed = parts.compactMap { part -> (part: SpotPart, letter: String, area: SheetArea)? in
            guard let letter = layout.letter(of: part), let area = layout.areas[letter] else { return nil }
            return (part, letter, area)
        }

        var frames: [String: Frame] = [:]
        for item in placed {
            let area = item.area
            let raw = rect(area)
            let under = placed.filter { $0.area.hits(area) && $0.area.size > area.size }
            let round = min(raw.width, raw.height, Self.maxRound)
            var place = raw
            var horizontal = Self.side(item.part.align, default: item.part.fillsWidth ? .fill : .center)
            var vertical = item.part.fillsHeight ? Side.fill : .center
            var clearTop: CGFloat = 0
            var clearBottom: CGFloat = 0

            if !under.isEmpty {
                let inset = Self.gap
                let side = { (isStart: Bool, isEnd: Bool) -> Side in isEnd ? .end : isStart ? .start : .center }
                horizontal = item.part.align.map { Self.side($0, default: .center) }
                    ?? side(under.contains { $0.area.x0 == area.x0 }, under.contains { $0.area.x1 == area.x1 })
                vertical = side(under.contains { $0.area.y0 == area.y0 }, under.contains { $0.area.y1 == area.y1 })
                if let line = (area.y0...area.y1).first(where: layout.hasDivider(inRow:)) {
                    place = CGRect(x: raw.minX, y: rowY[line], width: raw.width, height: Self.dividerHeight)
                    vertical = .center
                }
                if horizontal == .start { place = Self.moved(place, left: inset) }
                if horizontal == .end { place = Self.moved(place, right: inset) }
                if vertical == .start { place = Self.moved(place, top: inset) }
                if vertical == .end { place = Self.moved(place, bottom: inset) }
            }

            if case .text = item.part.control {
                for other in placed where other.area.hits(area) && other.area.size < area.size {
                    let crosses = other.area.y1 > area.y1 || other.area.y0 < area.y0
                    let reach = crosses ? Self.seamClearance : min(rect(other.area).height, Self.maxRound)
                    if other.area.y0 <= area.y0 {
                        clearTop = max(clearTop, reach)
                    } else if other.area.y1 >= area.y1 {
                        clearBottom = max(clearBottom, reach)
                    }
                }
            }

            frames[item.part.id] = Frame(
                rect: place,
                isOnTop: !under.isEmpty,
                horizontal: horizontal,
                vertical: vertical,
                roundSize: round,
                clearTop: clearTop,
                clearBottom: clearBottom
            )
        }

        self.frames = frames
        lines = rows.indices.filter(layout.hasDivider(inRow:)).map {
            CGRect(x: 0, y: rowY[$0], width: Self.width, height: Self.dividerHeight)
        }
        repeatFrame = repeatArea.map(rect)
        height = rows.isEmpty ? 0 : heights.reduce(0, +) + gaps
    }

    private static func side(_ align: SpotPart.Align?, default fallback: Side) -> Side {
        switch align {
        case nil: fallback
        case .left: .start
        case .center: .center
        case .right: .end
        }
    }

    private static func moved(_ rect: CGRect, left: CGFloat = 0, right: CGFloat = 0, top: CGFloat = 0, bottom: CGFloat = 0) -> CGRect {
        CGRect(x: rect.minX + left, y: rect.minY + top, width: rect.width - left - right, height: rect.height - top - bottom)
    }
}
