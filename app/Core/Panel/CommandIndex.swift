import Foundation

@MainActor
struct CommandIndex {
    private var list = ItemList()
    private var buttons: [String: CommandOffer] = [:]
    private var spots: [String: Spot] = [:]

    init() {}

    init(_ cards: [SpotsModel.Entry]) {
        var items: [SpotItem] = []
        for card in cards where card.spot.isFound && card.spot.fault == nil {
            spots[card.id] = card.spot
            items.append(SpotItem(title: card.state.title, run: card.id, keywords: [card.id]))
            guard card.spot.host == nil, card.spot.offers.count > 1 else { continue }
            for offer in card.spot.offers where offer.confirm == nil {
                let id = SpotsModel.Entry(spot: card.spot, item: Self.item(offer)).id
                items.append(SpotItem(title: offer.title, subtitle: card.state.title, run: id, keywords: [offer.id]))
                buttons[id] = offer
            }
        }
        list.replace(items)
    }

    func entries(matching query: SearchQuery, limit: Int, cards: [String: SpotsModel.Entry]) -> [SpotsModel.Entry] {
        query.matching(in: [list], limit: limit).compactMap { match in
            guard let offer = buttons[match.item.run] else { return cards[match.item.run] }
            return spots[String(match.item.run.prefix { $0 != "\n" })].map { SpotsModel.Entry(spot: $0, item: Self.item(offer)) }
        }
    }

    func button(of entry: SpotsModel.Entry) -> CommandOffer? {
        buttons[entry.id]
    }

    func command(of entry: SpotsModel.Entry) -> CommandOffer? {
        buttons[entry.id] ?? entry.spot.soleCommand.flatMap { id in entry.spot.offers.first { $0.id == id && $0.confirm == nil } }
    }

    private static func item(_ offer: CommandOffer) -> SpotItem {
        SpotItem(title: offer.title, run: offer.id, picture: Icon(text: offer.icon))
    }
}
