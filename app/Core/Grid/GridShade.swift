import Foundation

public struct GridShade: Equatable, Sendable {
    public struct Card: Equatable, Sendable, Identifiable {
        public let id: Int
        public let rect: CGRect
        public let edge: SurfaceEdge
    }

    public internal(set) var cards: [Card] = []
    public internal(set) var isOn = false
    public internal(set) var coversField = false

    public init() {}

    init(over placements: [SpotPlacement], leaving focused: Int, isOn: Bool) {
        cards = placements.filter { $0.index != focused }.map { Card(id: $0.index, rect: $0.rect, edge: SurfaceEdge(card: $0.size)) }
        self.isOn = isOn
        coversField = placements.contains { $0.index == focused }
    }
}
