import Foundation

@MainActor
struct CommandIndex {
    private var list = ItemList()
    private var buttons: [String: CommandAction] = [:]
    private var items: [String: SpotItem] = [:]
    private var spots: [String: Spot] = [:]
    private var chipActions: [AttachmentValue.Kind: ItemList] = [:]
    private var chipActionRows: [String: (spot: String, action: ChipAction)] = [:]
    private var fitting: (value: AttachmentValue, runs: Set<String>)?
    private(set) var fits = 0

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
        var chipRows: [AttachmentValue.Kind: [SpotItem]] = [:]
        for card in cards where card.spot.fault == nil {
            for action in card.spot.chipActions {
                let run = "\(card.id)\n\(action.name)"
                chipActionRows[run] = (card.id, action)
                let keywords = action.isDrop ? card.spot.keywords : [card.spot.name] + card.spot.keywords
                chipRows[action.kind, default: []].append(SpotItem(title: action.title, subtitle: action.detail, run: run, keywords: keywords))
            }
        }
        for kind in AttachmentValue.Kind.allCases {
            chipActions[kind, default: ItemList()].replace(chipRows[kind] ?? [])
        }
    }

    mutating func chipActions(of value: AttachmentValue, matching query: SearchQuery?, limit: Int) -> [(spot: String, action: ChipAction)] {
        guard let list = chipActions[value.kind] else { return [] }
        if fitting?.value != value {
            fits += 1
            fitting = (value, Set(chipActionRows.filter { $0.value.action.fits(value) }.keys))
        }
        let runs = fitting?.runs ?? []
        let rows = (query.map { $0.matching(in: [list]).map(\.item) } ?? list.all).filter { runs.contains($0.run) }.compactMap { chipActionRows[$0.run] }
        let actions = rows.filter { !$0.action.isDrop }
        let ranked = (actions.filter(\.action.isPatterned) + actions.filter { !$0.action.isPatterned }).prefix(limit)
        let spots = Set(ranked.map(\.spot))
        return Array((ranked + rows.filter { $0.action.isDrop && !spots.contains($0.spot) }).prefix(limit))
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
