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

    /// Lays out the grid once for each place in `places`, with the card moved there from `start` among cards of these sizes,
    /// in two groups from `split` on.
    public init(id: String, start: Int, sizes: [SpotSize], places: ClosedRange<Int>, split: Int? = nil) {
        self.id = id
        self.start = start
        place = start
        let grid = SpotGrid()
        layouts = Dictionary(uniqueKeysWithValues: places.map { place in
            var moved = sizes
            moved.insert(moved.remove(at: start), at: place)
            return (place, grid.place(moved, split: split))
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

    /// The move that keeps the lifted card inside these bounds, nearest to this move.
    public func capped(_ translation: CGSize, within bounds: CGRect) -> CGSize {
        let rect = rect(at: start)
        let x = min(max(translation.width, bounds.minX - rect.minX), bounds.maxX - rect.maxX)
        let y = min(max(translation.height, bounds.minY - rect.minY), bounds.maxY - rect.maxY)
        return CGSize(width: x, height: y)
    }

    /// Whether a release at this point lands on the grid: on its cards, or less than half a row past them.
    public func holds(_ point: CGPoint) -> Bool {
        let grid = CGRect(x: 0, y: 0, width: SpotTokens.gridWidth, height: SpotGrid.height(of: layout(at: start)))
        return grid.insetBy(dx: -SpotTokens.rowHeight / 2, dy: -SpotTokens.rowHeight / 2).contains(point)
    }

    private func distance(from point: CGPoint, to place: Int) -> CGFloat {
        let rect = rect(at: place)
        return hypot(rect.midX - point.x, rect.midY - point.y)
    }
}
