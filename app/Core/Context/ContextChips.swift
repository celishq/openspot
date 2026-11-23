import Foundation

public struct ContextChips: Equatable, Sendable {
    public static let limit = 3

    public private(set) var chips: [ContextChip] = [] {
        didSet { restack() }
    }
    public private(set) var selected: String? {
        didSet { restack() }
    }
    public private(set) var stack: [ContextChip] = []
    private var front: FrontApp?
    private var order: [String] = []

    public init() {}

    public var selectedChip: ContextChip? {
        chips.first { $0.source == selected }
    }

    public var isOn: Bool {
        selected != nil
    }

    public func appPath(of chip: ContextChip) -> String? {
        chip.app != nil && chip.app == front?.bundleID ? front?.path : nil
    }

    mutating func open(over front: FrontApp?, loading: [ContextChip]) {
        self.front = front
        selected = nil
        order = loading.map(\.source)
        chips = loading
        settle()
    }

    mutating func fill(_ source: String, with value: ContextValue, look: ContextChip.Look = ContextChip.Look()) {
        let chip = chips.first { $0.source == source } ?? ContextChip(source: source, app: nil)
        chips.removeAll { $0.source == source }
        chips.append(chip.filled(with: value, look: look))
        if !order.contains(source) { order.append(source) }
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
        guard !chips.isEmpty else { return }
        guard let selected, let index = chips.firstIndex(where: { $0.source == selected }) else {
            self.selected = chips[step < 0 ? chips.count - 1 : 0].source
            return
        }
        self.selected = chips[(index + step % chips.count + chips.count) % chips.count].source
    }

    mutating func leave() {
        selected = nil
    }

    private mutating func settle() {
        let place = Dictionary(order.enumerated().map { ($0.element, $0.offset) }, uniquingKeysWith: { first, _ in first })
        chips = Array(chips.sorted { ($0.rank(over: front?.bundleID), place[$0.source] ?? 0) < ($1.rank(over: front?.bundleID), place[$1.source] ?? 0) }.prefix(Self.limit))
        if let selected, !chips.contains(where: { $0.source == selected }) { self.selected = chips.first?.source }
    }

    private mutating func restack() {
        guard let index = chips.firstIndex(where: { $0.source == selected }) else {
            stack = chips
            return
        }
        stack = Array(chips[index...] + chips[..<index])
    }
}
