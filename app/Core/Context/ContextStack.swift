import Foundation

public struct ContextStack: Equatable, Sendable {
    public struct Place: Equatable, Sendable {
        public let chip: ContextChip
        public let slot: Int
        public let depth: Int
        public let showsKind: Bool
    }

    public static let limit = 6
    public static let pile = 3

    public let row: Int
    public private(set) var chips: [ContextChip] = []
    public private(set) var selected: String?
    public private(set) var isSpread = false
    public private(set) var placedSelection: String?
    public private(set) var places: [Place] = []
    public private(set) var rowCount = 0
    private var front: FrontApp?
    private var arrival: [String] = []
    private var order: [String] = []
    private var start = 0

    public init(row: Int = SpotTokens.contextRow) {
        self.row = row
    }

    public var selectedChip: ContextChip? {
        chips.first { $0.source == selected }
    }

    public var isOn: Bool {
        selected != nil
    }

    mutating func open(over front: FrontApp?, loading: [(source: String, look: ContextChip.Look)]) {
        self.front = front
        selected = nil
        arrival = loading.map(\.source)
        chips = loading.map { ContextChip(source: $0.source, app: front?.bundleID, look: look(of: front?.bundleID, kind: nil, else: $0.look)) }
        settle()
        order = []
        start = 0
        isSpread = false
        place(spreads: false)
    }

    mutating func fill(_ source: String, with value: ContextValue, look own: ContextChip.Look?) {
        let app = value.app ?? chips.first { $0.source == source }?.app
        chips.removeAll { $0.source == source }
        chips.append(ContextChip(source: source, app: app, look: look(of: app, kind: value.kind, else: own), state: .ready(value)))
        if !arrival.contains(source) { arrival.append(source) }
        settle()
    }

    mutating func end(_ source: String) {
        guard chips.contains(where: { $0.source == source && $0.isLoading }) else { return }
        remove(source)
    }

    mutating func remove(_ source: String) {
        chips.removeAll { $0.source == source }
        if selected == source { selected = chips.first?.source }
    }

    mutating func turn(by step: Int) {
        let order = shownOrder()
        guard !order.isEmpty else { return }
        guard let selected, let index = order.firstIndex(of: selected) else {
            self.selected = order[step < 0 ? order.count - 1 : 0]
            return
        }
        self.selected = order[(index + step % order.count + order.count) % order.count]
    }

    mutating func leave() {
        selected = nil
    }

    mutating func place(spreads: Bool) {
        let isSpread = spreads && selected != nil
        var order = shownOrder()
        if !isSpread, let selected, let index = order.firstIndex(of: selected) {
            order = Array(order[index...] + order[..<index])
        }
        let start = isSpread ? start(of: order.firstIndex { $0 == selected } ?? 0, count: order.count) : 0
        let byID = Dictionary(chips.map { ($0.source, $0) }, uniquingKeysWith: { first, _ in first })
        let apps = Dictionary(chips.compactMap { chip in chip.app.map { ($0, 1) } }, uniquingKeysWith: +)
        let row = row
        places = order.enumerated().compactMap { index, source in
            guard let chip = byID[source] else { return nil }
            let showsKind = chip.app.map { (apps[$0] ?? 0) > 1 } ?? false
            guard isSpread else { return Place(chip: chip, slot: 0, depth: index, showsKind: showsKind) }
            let slot = index - start
            return (0..<row).contains(slot)
                ? Place(chip: chip, slot: slot, depth: 0, showsKind: showsKind)
                : Place(chip: chip, slot: 0, depth: (slot + order.count) % order.count - row + 1, showsKind: showsKind)
        }
        placedSelection = selected
        self.isSpread = isSpread
        self.order = order
        self.start = start
        rowCount = isSpread ? min(order.count, row) : 0
    }

    private func shownOrder() -> [String] {
        let sources = chips.map(\.source)
        return order.filter(sources.contains) + sources.filter { !order.contains($0) }
    }

    private func start(of index: Int, count: Int) -> Int {
        let start = isSpread ? self.start : 0
        guard index >= start else { return index }
        return index < start + row ? min(start, max(count - row, 0)) : index - row + 1
    }

    private func look(of app: String?, kind: ContextValue.Kind?, else own: ContextChip.Look?) -> ContextChip.Look {
        if app != nil, app == front?.bundleID, let path = front?.path { return .file(FileIcon(path: path)) }
        guard let own, own != .symbol("") else { return .symbol(kind?.symbol ?? "ellipsis") }
        return own
    }

    private mutating func settle() {
        let place = Dictionary(arrival.enumerated().map { ($0.element, $0.offset) }, uniquingKeysWith: { first, _ in first })
        chips = Array(chips.sorted { ($0.rank(over: front?.bundleID), place[$0.source] ?? 0) < ($1.rank(over: front?.bundleID), place[$1.source] ?? 0) }.prefix(Self.limit))
        if let selected, !chips.contains(where: { $0.source == selected }) { self.selected = chips.first?.source }
    }
}
