import Foundation

@MainActor
struct CommandIndex {
    private var list = ItemList()
    private var buttons: [String: CommandAction] = [:]
    private var items: [String: SpotItem] = [:]
    private var spots: [String: Spot] = [:]
    private var takers: [AttachmentValue.Kind: ItemList] = [:]
    private var takerSpots: [String: Spot] = [:]

    init() {}

    init(_ cards: [SpotsModel.Entry]) {
        var rows: [SpotItem] = []
        for card in cards where card.isFound && card.spot.fault == nil {
            let commands = card.spot.host == nil ? card.spot.commands.map { (CommandAction.command($0), Icon(text: $0.icon)) } : []
            let own = card.spot.frameActions.filter { $0.scope == .spot }.map { ($0, Icon?.none) }
            for (action, icon) in commands + own where action.placeholder != nil && action.confirm == nil {
                let item = SpotItem(title: action.title, run: action.id, picture: icon)
                let id = SpotsModel.Entry(spot: card.spot, item: item).id
                rows.append(SpotItem(title: action.title, subtitle: card.state.title, run: id, keywords: [action.callName, card.id]))
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
        for kind in AttachmentValue.Kind.allCases {
            let cards = cards.filter { $0.spot.triggers.drop.takes(kind) }
            cards.forEach { takerSpots[$0.id] = $0.spot }
            takers[kind, default: ItemList()].replace(cards.map { SpotItem(title: $0.spot.name, subtitle: $0.spot.subtitle, run: $0.id, keywords: $0.spot.keywords) })
        }
    }

    func takers(of value: AttachmentValue, matching query: SearchQuery?, limit: Int) -> [(spot: String, title: String)] {
        guard let list = takers[value.kind] else { return [] }
        let rows = query.map { $0.matching(in: [list]).map(\.item) } ?? list.all
        return Array(rows.filter { takerSpots[$0.run]?.takes(value) == true }.map { ($0.run, $0.title) }.prefix(limit))
    }

    func entries(matching query: SearchQuery, text: String, limit: Int) -> [SpotsModel.Entry] {
        query.matching(in: [list], limit: limit).compactMap { match in
            guard let spot = spots[match.item.run], let item = items[match.item.run] else { return nil }
            let detail = text.isEmpty ? buttons[match.item.run]?.placeholder : "With \"\(text)\""
            return SpotsModel.Entry(spot: spot, item: item, role: .command, detail: detail)
        }
    }

    func button(of entry: SpotsModel.Entry) -> CommandAction? {
        buttons[entry.id]
    }

    func word(of entry: SpotsModel.Entry) -> String? {
        buttons[entry.id].map { action in
            if case .word = action.kind { action.title } else { action.callName }
        }
    }
}
