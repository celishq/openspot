import Foundation
import CoreGraphics

public struct SheetPlacement: Equatable, Sendable {
    public enum Side: Equatable, Sendable {
        case fill, start, center, end
    }

    public struct Frame: Equatable, Sendable {
        public let rect: CGRect
        public let isOnTop: Bool
        public let horizontal: Side
        public let vertical: Side
        public let roundSize: CGFloat
        public let clearTop: CGFloat
        public let clearBottom: CGFloat

        public var hasDetailUnderTitle: Bool {
            rect.height >= SpotTokens.listRow * 2
        }
    }

    public let frames: [String: Frame]
    public let lines: [CGRect]
    public let height: CGFloat
    public let repeatFrame: CGRect?
    private let topRoom: CGFloat

    public var overflows: Bool {
        height > SpotTokens.partsMaxHeight - topRoom
    }

    public init(parts: [SpotPart], layout: SheetLayout, searches: Bool = true, header: CGFloat = 0) {
        let rows = layout.rows
        let gap = SpotTokens.partGap
        let columns = max(rows.map(\.count).max() ?? 1, 1)
        let cell = (SpotTokens.partsWidth - gap * CGFloat(columns - 1)) / CGFloat(columns)
        let columnX = { (x: Int) in CGFloat(x) * (cell + gap) }

        var heights = rows.indices.map { layout.hasDivider(inRow: $0) ? SpotTokens.dividerHeight : SpotTokens.listRow }
        let repeatArea = layout.repeated.flatMap { layout.areas[$0.area] }
        topRoom = (repeatArea != nil && searches ? SpotTokens.partFieldRoom : 0) + header
        var fillRows = Set<Int>()
        for part in parts where repeatArea == nil {
            guard let letter = layout.letter(of: part), let area = layout.areas[letter] else { continue }
            guard part.growsRow else { continue }
            for y in area.y0...area.y1 where !layout.hasDivider(inRow: y) { fillRows.insert(y) }
        }
        if let repeatArea {
            for y in repeatArea.y0...repeatArea.y1 where !layout.hasDivider(inRow: y) { fillRows.insert(y) }
        }
        var rowGaps = Array(repeating: gap, count: max(rows.count - 1, 0))
        if let first = Self.firstEndButtonRow(parts: parts, layout: layout), first > 0 { rowGaps[first - 1] = SpotTokens.partGroupGap }
        let gaps = rowGaps.reduce(0, +)
        var filled: CGFloat?
        if !fillRows.isEmpty {
            let room = SpotTokens.partsMaxHeight - topRoom
            let free = room - heights.reduce(0, +) - gaps
            if free > 0 {
                for y in fillRows { heights[y] += free / CGFloat(fillRows.count) }
                filled = room
            }
        }

        var rowY: [CGFloat] = []
        var y: CGFloat = 0
        for (index, row) in heights.enumerated() {
            rowY.append(y)
            y += row + (rowGaps.indices.contains(index) ? rowGaps[index] : gap)
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
            let round = min(raw.width, raw.height, SpotTokens.partMaxRound)
            var place = raw
            var horizontal = Self.side(item.part.align, default: item.part.fillsWidth ? .fill : .center)
            var vertical = item.part.fillsHeight ? Side.fill : .center
            var clearTop: CGFloat = 0
            var clearBottom: CGFloat = 0

            if !under.isEmpty {
                let inset = SpotTokens.partGap
                let side = { (isStart: Bool, isEnd: Bool) -> Side in isEnd ? .end : isStart ? .start : .center }
                horizontal = item.part.align.map { Self.side($0, default: .center) }
                    ?? side(under.contains { $0.area.x0 == area.x0 }, under.contains { $0.area.x1 == area.x1 })
                vertical = side(under.contains { $0.area.y0 == area.y0 }, under.contains { $0.area.y1 == area.y1 })
                if let line = (area.y0...area.y1).first(where: layout.hasDivider(inRow:)) {
                    place = CGRect(x: raw.minX, y: rowY[line], width: raw.width, height: SpotTokens.dividerHeight)
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
                    let reach = crosses ? SpotTokens.partSeamClearance : min(rect(other.area).height, SpotTokens.partMaxRound)
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
            CGRect(x: 0, y: rowY[$0], width: SpotTokens.partsWidth, height: SpotTokens.dividerHeight)
        }
        repeatFrame = repeatArea.map(rect)
        height = rows.isEmpty ? 0 : filled ?? heights.reduce(0, +) + gaps
    }

    private static func firstEndButtonRow(parts: [SpotPart], layout: SheetLayout) -> Int? {
        let isButtons = { (row: Int) -> Bool in
            guard !layout.hasDivider(inRow: row) else { return false }
            let held = parts.compactMap { part in layout.letter(of: part).flatMap { layout.areas[$0] }.map { (part, $0) } }
                .filter { $0.1.y0 <= row && $0.1.y1 >= row }
            return !held.isEmpty && held.allSatisfy { $0.0.isPressable && $0.1.y0 == row && $0.1.y1 == row }
        }
        var first: Int?
        for row in layout.rows.indices.reversed() {
            guard isButtons(row) else { break }
            first = row
        }
        return first
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
