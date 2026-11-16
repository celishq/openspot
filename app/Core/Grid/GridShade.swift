import Foundation

public struct GridShade: Equatable, Sendable {
    public internal(set) var dimmed: Set<Int> = []
    public internal(set) var isOn = false
    public internal(set) var coversField = false
    public internal(set) var focused: Int?
    public internal(set) var lift: CGFloat = 0

    public init() {}

    init(over placements: [SpotPlacement], leaving focused: Int, isOn: Bool, lift: CGFloat) {
        dimmed = Set(placements.map(\.index).filter { $0 != focused })
        self.isOn = isOn
        coversField = placements.contains { $0.index == focused }
        self.focused = coversField ? focused : nil
        self.lift = lift
    }

    public func dims(_ index: Int) -> Bool {
        isOn && dimmed.contains(index)
    }

    public func offset(of index: Int) -> CGFloat {
        isOn && index == focused ? lift : 0
    }
}
