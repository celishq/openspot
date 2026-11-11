import Foundation

/// A card that the person drags over the grid in Edit Spots: where it started, where a release puts it now, and the layout
/// of the grid for each target that it may take.
public struct SpotDrag: Equatable, Sendable {
    /// A place in the order of the cards, in the group of the cards on the grid or of the hidden cards.
    public struct Target: Hashable, Sendable {
        public let place: Int
        public let isOnGrid: Bool

        public static func onGrid(_ place: Int) -> Target {
            Target(place: place, isOnGrid: true)
        }

        public static func hidden(_ place: Int) -> Target {
            Target(place: place, isOnGrid: false)
        }
    }

    public let id: String
    /// Where the card lay when the drag started.
    public let home: Target
    /// Where a release puts the card.
    public var target: Target
    private let layouts: [Target: [SpotPlacement]]

    /// The card's place in the order when the drag started.
    public var start: Int {
        home.place
    }

    /// The card's place in the order where a release puts it.
    public var place: Int {
        target.place
    }

    /// Lays out the grid once for each place in `places` on the grid, with the card moved there from `start` among cards of
    /// these sizes.
    public init(id: String, start: Int, sizes: [SpotSize], places: ClosedRange<Int>, grid: SpotGrid = SpotGrid()) {
        self.init(id: id, home: .onGrid(start), sizes: sizes, targets: places.map(Target.onGrid), grid: grid)
    }

    /// Lays out the grid once for each target, with the card moved there from `home` among cards of these sizes. The cards
    /// on the grid come before the grid's split, the card among them when its home is on the grid; a target moves the split
    /// by the card's change of group.
    public init(id: String, home: Target, sizes: [SpotSize], targets: [Target], grid: SpotGrid) {
        self.id = id
        self.home = home
        target = home
        layouts = Dictionary(uniqueKeysWithValues: targets.map { target in
            var moved = sizes
            moved.insert(moved.remove(at: home.place), at: target.place)
            let shift = (target.isOnGrid ? 1 : 0) - (home.isOnGrid ? 1 : 0)
            return (target, grid.moving(home.place, to: target.place, split: grid.split.map { $0 + shift }).place(moved))
        })
    }

    /// The places of the cards when the card lands at this target, in the order that the landing gives.
    public func layout(at target: Target) -> [SpotPlacement] {
        layouts[target] ?? []
    }

    /// Where the card lies, and its size, when it lands at this target.
    public func placement(at target: Target) -> SpotPlacement? {
        layout(at: target).first { $0.index == target.place }
    }

    public func rect(at target: Target) -> CGRect {
        placement(at: target)?.rect ?? .zero
    }

    /// The target whose landing puts the card's centre nearest to this point. A tie keeps the lower place, on the grid first.
    public func nearest(to point: CGPoint) -> Target {
        layouts.keys.min { lhs, rhs in
            (distance(from: point, to: lhs), lhs.place, lhs.isOnGrid ? 0 : 1) < (distance(from: point, to: rhs), rhs.place, rhs.isOnGrid ? 0 : 1)
        } ?? home
    }

    /// The centre of the lifted card when the pointer has moved this far from where the drag started.
    public func centre(movedBy translation: CGSize) -> CGPoint {
        let rect = rect(at: home)
        return CGPoint(x: rect.midX + translation.width, y: rect.midY + translation.height)
    }

    /// The move that keeps the lifted card inside these bounds, nearest to this move.
    public func capped(_ translation: CGSize, within bounds: CGRect) -> CGSize {
        let rect = rect(at: home)
        let x = min(max(translation.width, bounds.minX - rect.minX), bounds.maxX - rect.maxX)
        let y = min(max(translation.height, bounds.minY - rect.minY), bounds.maxY - rect.maxY)
        return CGSize(width: x, height: y)
    }

    /// Whether a release at this point lands on the grid: on its cards, or less than half a row past them.
    public func holds(_ point: CGPoint) -> Bool {
        let grid = CGRect(x: 0, y: 0, width: SpotTokens.gridWidth, height: SpotGrid.height(of: layout(at: home)))
        return grid.insetBy(dx: -SpotTokens.rowHeight / 2, dy: -SpotTokens.rowHeight / 2).contains(point)
    }

    private func distance(from point: CGPoint, to target: Target) -> CGFloat {
        let rect = rect(at: target)
        return hypot(rect.midX - point.x, rect.midY - point.y)
    }
}
