import Foundation

public struct ContextSpread: Equatable, Sendable {
    public struct Place: Equatable, Sendable {
        public let chip: ContextChip
        public let slot: Int
        public let depth: Int
        public let showsKind: Bool
    }

    public static let row = 3

    public private(set) var isSpread = false
    public private(set) var selected: String?
    public private(set) var places: [Place] = []
    public private(set) var rowCount = 0
    private var order: [String] = []

    public init() {}

    func order(over chips: [ContextChip]) -> [String] {
        let sources = chips.map(\.source)
        return order.filter(sources.contains) + sources.filter { !order.contains($0) }
    }

    func next(over chips: [ContextChip], selected: String?, spreads: Bool) -> ContextSpread {
        var next = ContextSpread()
        next.selected = selected
        next.isSpread = spreads && selected != nil
        var order = order(over: chips)
        if !next.isSpread, let selected, let index = order.firstIndex(of: selected) {
            order = Array(order[index...] + order[..<index])
        }
        next.order = order
        let byID = Dictionary(chips.map { ($0.source, $0) }, uniquingKeysWith: { first, _ in first })
        let apps = Dictionary(chips.compactMap { chip in chip.app.map { ($0, 1) } }, uniquingKeysWith: +)
        next.places = order.enumerated().compactMap { index, source in
            guard let chip = byID[source] else { return nil }
            let showsKind = chip.app.map { (apps[$0] ?? 0) > 1 } ?? false
            guard next.isSpread else { return Place(chip: chip, slot: 0, depth: index, showsKind: showsKind) }
            return index < Self.row
                ? Place(chip: chip, slot: index, depth: 0, showsKind: showsKind)
                : Place(chip: chip, slot: 0, depth: index - Self.row + 1, showsKind: showsKind)
        }
        next.rowCount = next.isSpread ? min(order.count, Self.row) : 0
        return next
    }
}
