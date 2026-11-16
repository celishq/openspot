import Foundation

public struct GridShade: Equatable, Sendable {
    public internal(set) var dimmed: Set<Int> = []
    public internal(set) var isOn = false
    public internal(set) var coversField = false

    public init() {}

    init(over placements: [SpotPlacement], leaving focused: Int, isOn: Bool) {
        dimmed = Set(placements.map(\.index).filter { $0 != focused })
        self.isOn = isOn
        coversField = placements.contains { $0.index == focused }
    }

    public func dims(_ index: Int) -> Bool {
        isOn && dimmed.contains(index)
    }
}
