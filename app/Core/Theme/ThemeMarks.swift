import Foundation

public struct ThemeMarks: Equatable, Sendable {
    public let all: [ThemeMark]

    public init() {
        all = []
    }

    public init(sizes: SpotSizes, cards: [(placement: SpotPlacement, isPadded: Bool)], scroll: CGFloat = 0, sheet: CGRect? = nil) {
        if let sheet {
            all = Self.corners(of: sheet, radius: sizes.radius) + Self.padding(of: sheet, by: sizes.padding)
            return
        }
        let rects = cards.map { Self.rect(of: $0.placement, sizes: sizes).offsetBy(dx: SpotTokens.halo, dy: sizes.gridTop - scroll) }
        var corners: [ThemeMark] = []
        var edges: [ThemeMark] = []
        var gaps: [ThemeMark] = []
        var padding: [ThemeMark] = []
        for (card, rect) in zip(cards, rects) {
            let size = card.placement.size
            let isRound = size.rows == 1 && size.columns < SpotTokens.columns
            if !isRound { corners += Self.corners(of: rect, radius: sizes.radius) }
            edges += Self.edges(of: rect, placement: card.placement, corner: isRound ? 0 : Self.cornerSide(sizes.radius))
            if card.isPadded { padding += Self.padding(of: rect, by: sizes.padding) }
            if rects.contains(where: { abs($0.minX - rect.maxX - sizes.columnGap) < 1 && $0.minY < rect.maxY && $0.maxY > rect.minY }) {
                gaps.append(ThemeMark(section: "space", key: "column-gap", rect: CGRect(x: rect.maxX, y: rect.minY, width: sizes.columnGap, height: rect.height), axis: CGVector(dx: 1, dy: 0)))
            }
            if rects.contains(where: { abs($0.minY - rect.maxY - sizes.rowGap) < 1 && $0.minX < rect.maxX && $0.maxX > rect.minX }) {
                gaps.append(ThemeMark(section: "space", key: "row-gap", rect: CGRect(x: rect.minX, y: rect.maxY, width: rect.width, height: sizes.rowGap), axis: CGVector(dx: 0, dy: 1)))
            }
        }
        all = corners + edges + gaps + padding
    }

    public func mark(at point: CGPoint) -> ThemeMark? {
        index(at: point).map { all[$0] }
    }

    public func index(at point: CGPoint) -> Int? {
        all.firstIndex { $0.hit.contains(point) }
    }

    private static func rect(of placement: SpotPlacement, sizes: SpotSizes) -> CGRect {
        let top: CGFloat = placement.group == nil ? 0 : placement.group == .grid ? SpotTokens.groupTitleBand : 2 * SpotTokens.groupTitleBand
        let columns = CGFloat(placement.size.columns)
        let rows = CGFloat(placement.size.rows)
        return CGRect(
            x: CGFloat(placement.column) * (sizes.cell + sizes.columnGap),
            y: CGFloat(placement.row) * (sizes.cell + sizes.rowGap) + top,
            width: columns * sizes.cell + (columns - 1) * sizes.columnGap,
            height: rows * sizes.cell + (rows - 1) * sizes.rowGap
        )
    }

    private static func cornerSide(_ radius: CGFloat) -> CGFloat {
        max(radius / 2, SpotTokens.themeMarkCorner)
    }

    private static func corners(of rect: CGRect, radius: CGFloat) -> [ThemeMark] {
        let side = cornerSide(radius)
        let inward = 1 / 2.0.squareRoot()
        return [(rect.minX, rect.minY, 1.0, 1.0), (rect.maxX, rect.minY, -1, 1), (rect.minX, rect.maxY, 1, -1), (rect.maxX, rect.maxY, -1, -1)].map { x, y, dx, dy in
            let square = { (length: CGFloat) in CGRect(x: dx > 0 ? x : x - length, y: dy > 0 ? y : y - length, width: length, height: length) }
            return ThemeMark(
                section: "radius", key: "card", rect: square(radius), hit: square(side),
                shape: .arc(centre: CGPoint(x: x + dx * radius, y: y + dy * radius), radius: radius),
                axis: CGVector(dx: dx * inward, dy: dy * inward)
            )
        }
    }

    private static func edges(of rect: CGRect, placement: SpotPlacement, corner: CGFloat) -> [ThemeMark] {
        let half = SpotTokens.themeMarkEdge / 2
        return [
            ThemeMark(
                section: "space", key: "cell",
                rect: CGRect(x: rect.maxX - half, y: rect.minY + corner, width: 2 * half, height: rect.height - 2 * corner),
                axis: CGVector(dx: 1, dy: 0), rate: 1 / CGFloat(placement.column + placement.size.columns)
            ),
            ThemeMark(
                section: "space", key: "cell",
                rect: CGRect(x: rect.minX + corner, y: rect.maxY - half, width: rect.width - 2 * corner, height: 2 * half),
                axis: CGVector(dx: 0, dy: 1), rate: 1 / CGFloat(placement.row + placement.size.rows)
            )
        ]
    }

    private static func padding(of rect: CGRect, by inset: CGFloat) -> [ThemeMark] {
        let band = { (x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat, dx: CGFloat, dy: CGFloat) in
            ThemeMark(section: "space", key: "padding", rect: CGRect(x: x, y: y, width: width, height: height), axis: CGVector(dx: dx, dy: dy))
        }
        return [
            band(rect.minX, rect.minY, inset, rect.height, 1, 0),
            band(rect.maxX - inset, rect.minY, inset, rect.height, -1, 0),
            band(rect.minX, rect.minY, rect.width, inset, 0, 1),
            band(rect.minX, rect.maxY - inset, rect.width, inset, 0, -1)
        ]
    }
}
