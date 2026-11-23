import Foundation

public struct ContextSpread: Equatable, Sendable {
    public struct Place: Equatable, Sendable {
        public let chip: ContextChip
        public let slot: Int
        public let depth: Int
    }

    public static let row = 3

    public private(set) var isSpread = false
    public private(set) var selected: String?
    public private(set) var places: [Place] = []
    public private(set) var rowCount = 0

    public init() {}

    func next(over chips: [ContextChip], selected: String?, spreads: Bool) -> ContextSpread {
        var next = ContextSpread()
        next.selected = selected
        next.isSpread = spreads && selected != nil
        guard next.isSpread else {
            next.places = order(of: chips, front: selected).enumerated().map { Place(chip: $0.element, slot: 0, depth: $0.offset) }
            return next
        }
        let start = max(0, (chips.firstIndex { $0.source == selected } ?? 0) - Self.row + 1)
        var depth = 0
        next.places = chips.enumerated().map { index, chip in
            guard !(start..<start + Self.row).contains(index) else { return Place(chip: chip, slot: index - start, depth: 0) }
            depth += 1
            return Place(chip: chip, slot: 0, depth: depth)
        }
        next.rowCount = min(chips.count, Self.row)
        return next
    }

    private func order(of chips: [ContextChip], front: String?) -> [ContextChip] {
        if let front, let index = chips.firstIndex(where: { $0.source == front }) {
            return Array(chips[index...] + chips[..<index])
        }
        let kept = places.compactMap { place in chips.first { $0.source == place.chip.source } }
        return kept + chips.filter { chip in !kept.contains { $0.source == chip.source } }
    }
}
