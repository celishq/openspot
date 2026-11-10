import Foundation

/// A card that the person drags over the grid in Edit Spots: where it started, where a release puts it now, and the layout
/// of the grid for each place in the order that it may take.
public struct SpotDrag: Equatable, Sendable {
    public let id: String
    /// The card's place in the order when the drag started.
    public let start: Int
    /// The card's place in the order where a release puts it.
    public var place: Int
    private let layouts: [Int: [SpotPlacement]]
    /// The width of the grid.
    private let width: CGFloat

    /// Lays out the grid once for each place in `places`, with the card moved there from `start` among cards of these sizes.
    /// With `rows`, it leaves out each place, but the start, where the first `counted` cards reach past that many rows.
    public init(id: String, start: Int, sizes: [SpotSize], places: ClosedRange<Int>, grid: SpotGrid = SpotGrid(), rows: Int? = nil, counted: Int? = nil) {
        self.id = id
        self.start = start
        place = start
        width = SpotTokens.width(columns: grid.columns)
        let counted = counted ?? sizes.count
        layouts = Dictionary(uniqueKeysWithValues: places.compactMap { place in
            var moved = sizes
            moved.insert(moved.remove(at: start), at: place)
            let layout = grid.place(moved)
            let reach = layout.filter { $0.index < counted }.map { $0.row + $0.size.rows }.max() ?? 0
            guard place == start || rows.map({ reach <= $0 }) ?? true else { return nil }
            return (place, layout)
        })
    }

    /// The places of the cards when the card lands at this place, in the order that the landing gives.
    public func layout(at place: Int) -> [SpotPlacement] {
        layouts[place] ?? []
    }

    /// Where the card lies, and its size, when it lands at this place.
    public func placement(at place: Int) -> SpotPlacement? {
        layout(at: place).first { $0.index == place }
    }

    public func rect(at place: Int) -> CGRect {
        placement(at: place)?.rect ?? .zero
    }

    /// The place whose landing puts the card's centre nearest to this point. A tie keeps the lower place.
    public func nearest(to point: CGPoint) -> Int {
        layouts.keys.min { lhs, rhs in
            (distance(from: point, to: lhs), lhs) < (distance(from: point, to: rhs), rhs)
        } ?? start
    }

    /// The centre of the lifted card when the pointer has moved this far from where the drag started.
    public func centre(movedBy translation: CGSize) -> CGPoint {
        let rect = rect(at: start)
        return CGPoint(x: rect.midX + translation.width, y: rect.midY + translation.height)
    }

    /// Whether a release at this point lands on the grid: on its cards, or less than half a row past them.
    public func holds(_ point: CGPoint) -> Bool {
        let rows = layout(at: start).map { $0.row + $0.size.rows }.max() ?? 0
        let grid = CGRect(x: 0, y: 0, width: width, height: SpotTokens.height(rows: rows))
        return grid.insetBy(dx: -SpotTokens.rowHeight / 2, dy: -SpotTokens.rowHeight / 2).contains(point)
    }

    private func distance(from point: CGPoint, to place: Int) -> CGFloat {
        let rect = rect(at: place)
        return hypot(rect.midX - point.x, rect.midY - point.y)
    }
}
