import Foundation

public struct SpotDrag: Equatable, Sendable {
    public struct Target: Hashable, Sendable {
        public let place: Int
        public let isOnGrid: Bool
        public var panel = GridPanel.center

        public static func onGrid(_ place: Int, panel: GridPanel = .center) -> Target {
            Target(place: place, isOnGrid: true, panel: panel)
        }

        public static func shelf(_ place: Int) -> Target {
            Target(place: place, isOnGrid: false)
        }
    }

    public let id: String
    public let home: Target
    public var target: Target
    private let layouts: [Target: [SpotPlacement]]
    private let columns: Int

    public var start: Int {
        home.place
    }

    public var place: Int {
        target.place
    }

    public init(id: String, start: Int, sizes: [SpotSize], places: ClosedRange<Int>, grid: SpotGrid = SpotGrid()) {
        self.init(id: id, home: .onGrid(start), sizes: sizes, targets: places.map { Target.onGrid($0) }, grid: grid)
    }

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

    public func layout(at target: Target) -> [SpotPlacement] {
        layouts[target] ?? []
    }

    public func placement(at target: Target) -> SpotPlacement? {
        layout(at: target).first { $0.index == target.place }
    }

    public func rect(at target: Target) -> CGRect {
        placement(at: target)?.rect ?? .zero
    }

    public func nearest(to point: CGPoint) -> Target {
        let rank = { (target: Target) in (target.place, target.isOnGrid ? 0 : 1, target.panel == .center ? 0 : target.panel == .left ? 1 : 2) }
        return layouts.keys.min { lhs, rhs in
            let (left, right) = (rank(lhs), rank(rhs))
            return (distance(from: point, to: lhs), left.0, left.1, left.2) < (distance(from: point, to: rhs), right.0, right.1, right.2)
        } ?? home
    }

    public func centre(movedBy translation: CGSize) -> CGPoint {
        let rect = rect(at: home)
        return CGPoint(x: rect.midX + translation.width, y: rect.midY + translation.height)
    }

    public func capped(_ translation: CGSize, within bounds: CGRect) -> CGSize {
        let rect = rect(at: home)
        let x = min(max(translation.width, bounds.minX - rect.minX), bounds.maxX - rect.maxX)
        let y = min(max(translation.height, bounds.minY - rect.minY), bounds.maxY - rect.maxY)
        return CGSize(width: x, height: y)
    }

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
