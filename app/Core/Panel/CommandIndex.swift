import Foundation

@MainActor
struct CommandIndex {
    private var list = ItemList()
    private var buttons: [String: CommandAction] = [:]
    private var items: [String: SpotItem] = [:]
    private var spots: [String: Spot] = [:]

    init() {}

    init(_ cards: [SpotsModel.Entry]) {
        var rows: [SpotItem] = []
        for card in cards where card.isFound && card.spot.fault == nil {
            let offers = card.spot.host == nil ? card.spot.offers.map { (CommandAction.command($0), Icon(text: $0.icon)) } : []
            let own = card.spot.actions.filter { $0.scope == .spot }.map { ($0, Icon?.none) }
            for (action, icon) in offers + own where action.placeholder != nil && action.confirm == nil {
                let item = SpotItem(title: action.title, run: action.id, picture: icon)
                let id = SpotsModel.Entry(spot: card.spot, item: item).id
                rows.append(SpotItem(title: action.title, subtitle: card.state.title, run: id, keywords: [CommandAction.command(of: action) ?? action.id, card.id]))
                buttons[id] = action
                items[id] = item
                spots[id] = card.spot
            }
            for (name, word) in card.spot.host == nil ? card.commandWords : [] {
                let action = CommandAction.word(name, shown: word)
                let item = SpotItem(title: action.title, run: action.id)
                let id = SpotsModel.Entry(spot: card.spot, item: item).id
                rows.append(SpotItem(title: action.title, subtitle: card.state.title, run: id, keywords: [word, card.id]))
                buttons[id] = action
                items[id] = item
                spots[id] = card.spot
            }
        }
        list.replace(rows)
    }

    func entries(matching query: SearchQuery, text: String, limit: Int) -> [SpotsModel.Entry] {
        query.matching(in: [list], limit: limit).compactMap { match in
            guard let spot = spots[match.item.run], let item = items[match.item.run] else { return nil }
            let detail = text.isEmpty ? buttons[match.item.run]?.placeholder : "With \"\(text)\""
            return SpotsModel.Entry(spot: spot, item: item, detail: detail)
        }
    }

    func button(of entry: SpotsModel.Entry) -> CommandAction? {
        buttons[entry.id]
    }
}
