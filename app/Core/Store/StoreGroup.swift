import Foundation

public struct StoreGroup: Identifiable, Equatable, Sendable {
    public let title: String?
    public let cards: [StoreCard]

    public var id: String {
        title ?? ""
    }

    static func of(_ cards: [StoreCard], at place: StorePlace) -> [StoreGroup] {
        guard place == .mine else { return cards.isEmpty ? [] : [StoreGroup(title: nil, cards: cards)] }
        let groups = [
            StoreGroup(title: "Updates", cards: cards.filter { $0.mark == .update }),
            StoreGroup(title: "Yours", cards: cards.filter { $0.mark != .update && $0.mark != .core }),
            StoreGroup(title: "Comes with Openspot", cards: cards.filter { $0.mark == .core })
        ].filter { !$0.cards.isEmpty }
        return groups.count > 1 ? groups : groups.map { StoreGroup(title: nil, cards: $0.cards) }
    }

    static func summary(of cards: [StoreCard]) -> String {
        let core = cards.filter { $0.mark == .core }.count
        return ["\(cards.count - core) yours", core > 0 ? "\(core) \(core == 1 ? "comes" : "come") with Openspot" : nil].compactMap { $0 }.joined(separator: " · ")
    }
}
