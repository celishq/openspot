import Foundation

/// A card that the person drags over the grid in Edit Spots: where it started, where a release puts it now, and the layout
/// of the grid for each target that it may take.
public struct SpotDrag: Equatable, Sendable {
    /// A place in the order of the cards, in the group of the cards on the grid or on the shelf.
    public struct Target: Hashable, Sendable {
        public let place: Int
        public let isOnGrid: Bool
        /// The panel that the card lies in, on the grid.
        public var panel = GridPanel.center

        public static func onGrid(_ place: Int, panel: GridPanel = .center) -> Target {
            Target(place: place, isOnGrid: true, panel: panel)
        }

        public static func shelf(_ place: Int) -> Target {
            Target(place: place, isOnGrid: false)
        }
    }

    public let id: String
    /// Where the card lay when the drag started.
    public let home: Target
    /// Where a release puts the card.
    public var target: Target
    private let layouts: [Target: [SpotPlacement]]
    /// How many columns the grid has.
    private let columns: Int

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
        self.init(id: id, home: .onGrid(start), sizes: sizes, targets: places.map { Target.onGrid($0) }, grid: grid)
    }

    /// Lays out the grid once for each target, with the card moved there from `home` among cards of these sizes. The cards
    /// on the grid come before the grid's split, the card among them when its home is on the grid; a target moves the split
    /// by the card's change of group.
    public init(id: String, home: Target, sizes: [SpotSize], targets: [Target], grid: SpotGrid) {
        columns = grid.panels.columns
        self.id = id
        self.home = home
        target = home
        layouts = Dictionary(uniqueKeysWithValues: targets.map { target in
            var moved = sizes
            moved.insert(moved.remove(at: home.place), at: target.place)
            let shift = (target.isOnGrid ? 1 : 0) - (home.isOnGrid ? 1 : 0)
            return (target, grid.moving(home.place, to: target.place, split: grid.split.map { $0 + shift }).placing(target.place, on: target.panel).place(moved))
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

    /// The target whose landing puts the card's centre nearest to this point. A tie keeps the lower place, on the grid first,
    /// in the center first.
    public func nearest(to point: CGPoint) -> Target {
        let rank = { (target: Target) in (target.place, target.isOnGrid ? 0 : 1, target.panel == .center ? 0 : target.panel == .left ? 1 : 2) }
        return layouts.keys.min { lhs, rhs in
            let (left, right) = (rank(lhs), rank(rhs))
            return (distance(from: point, to: lhs), left.0, left.1, left.2) < (distance(from: point, to: rhs), right.0, right.1, right.2)
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

    /// Whether a release at this point lands on the grid: on the cards of any of its layouts, such as the group of search
    /// only that a target opens under the grid, or less than half a row past them.
    public func holds(_ point: CGPoint) -> Bool {
        let height = layouts.values.map(SpotGrid.height(of:)).max() ?? 0
        let grid = CGRect(x: 0, y: 0, width: SpotTokens.width(columns: columns), height: height)
        return grid.insetBy(dx: -SpotTokens.rowHeight / 2, dy: -SpotTokens.rowHeight / 2).contains(point)
    }

    private func distance(from point: CGPoint, to target: Target) -> CGFloat {
        let rect = rect(at: target)
        return hypot(rect.midX - point.x, rect.midY - point.y)
    }
}
