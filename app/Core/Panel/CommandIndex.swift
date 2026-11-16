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
            let offers = card.spot.host == nil ? card.spot.offers.filter { $0.confirm == nil } : []
            for offer in offers where offer.placeholder != nil {
                let id = SpotsModel.Entry(spot: card.spot, item: Self.item(offer)).id
                items.append(SpotItem(title: offer.title, subtitle: card.state.title, run: id, keywords: [offer.id, card.id]))
                buttons[id] = offer
                spots[id] = card.spot
            }
            if offers.isEmpty, card.spot.placeholder != nil {
                let id = SpotsModel.Entry(spot: card.spot, item: Self.item(of: card)).id
                items.append(SpotItem(title: card.state.title, run: id, keywords: [card.id]))
                spots[id] = card.spot
            }
        }
        list.replace(items)
    }

    func entries(matching query: SearchQuery, text: String, limit: Int, cards: [String: SpotsModel.Entry]) -> [SpotsModel.Entry] {
        query.matching(in: [list], limit: limit).compactMap { match in
            guard let spot = spots[match.item.run] else { return nil }
            let offer = buttons[match.item.run]
            let detail = text.isEmpty ? offer?.placeholder ?? spot.placeholder : "With \"\(text)\""
            let item = offer.map(Self.item) ?? cards[spot.id].map(Self.item(of:)) ?? SpotItem(title: spot.name, run: "")
            return SpotsModel.Entry(spot: spot, item: item, detail: detail)
        }
    }

    func button(of entry: SpotsModel.Entry) -> CommandOffer? {
        buttons[entry.id]
    }

    private static func item(_ offer: CommandOffer) -> SpotItem {
        SpotItem(title: offer.title, run: offer.id, picture: Icon(text: offer.icon))
    }

    private static func item(of card: SpotsModel.Entry) -> SpotItem {
        SpotItem(title: card.state.title, run: "")
    }
}
