import Foundation

public struct StoreGroup: Identifiable, Equatable, Sendable {
    public let title: String?
    public let cards: [StoreCard]
    public let folds: Bool

    public var id: String {
        title ?? ""
    }

    static func of(_ cards: [StoreCard], at place: StorePlace) -> [StoreGroup] {
        guard place == .mine else { return cards.isEmpty ? [] : [StoreGroup(title: nil, cards: cards, folds: false)] }
        let groups = [
            StoreGroup(title: "Updates", cards: cards.filter { $0.mark == .update }, folds: false),
            StoreGroup(title: "Yours", cards: cards.filter { $0.mark != .update && $0.mark != .core }, folds: false),
            StoreGroup(title: "Comes with Openspot", cards: cards.filter { $0.mark == .core }, folds: true)
        ].filter { !$0.cards.isEmpty }
        return groups.count > 1 ? groups : groups.map { StoreGroup(title: nil, cards: $0.cards, folds: false) }
    }
}
