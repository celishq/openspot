import Foundation

extension SpotsModel {
    func takeCommands() {
        var items: [SpotItem] = []
        var offers: [String: CommandOffer] = [:]
        for card in cards where card.spot.isFound && card.spot.fault == nil {
            items.append(SpotItem(title: card.state.title, run: card.id, keywords: [card.id]))
            guard card.spot.host == nil, card.spot.offers.count > 1 else { continue }
            for offer in card.spot.offers where offer.confirm == nil {
                let id = Entry(spot: card.spot, item: Self.commandItem(offer)).id
                items.append(SpotItem(title: offer.title, subtitle: card.state.title, run: id, keywords: [offer.id]))
                offers[id] = offer
            }
        }
        commandList.replace(items)
        commandOffers = offers
    }

    func commandEntries(_ command: SlashCommand) -> [Entry] {
        let spots = Dictionary(cards.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        return runs.search(of: command.word).matching(in: [commandList], limit: command.word.isEmpty ? .max : Self.searchLimit).compactMap { match in
            if let offer = commandOffers[match.item.run] {
                let spot = spots[String(match.item.run.prefix { $0 != "\n" })]
                return spot.map { Entry(spot: $0.spot, item: Self.commandItem(offer)) }
            }
            return spots[match.item.run]
        }
    }

    func launch(_ shown: Entry, with text: String) {
        guard let entry = entry(shown.spot.id) else { return }
        let offer = commandOffer(of: shown)
        if text.isEmpty {
            if let offer, shown.item != nil { return run(CommandAction.command(offer), on: (entry, nil)) }
            return run(seen: shown)
        }
        if let offer {
            return call(CommandAction(id: offer.id, title: offer.title, scope: .spot, after: offer.closes ? .close : .stay), of: entry, text)
        }
        switch entry.kind {
        case .launch:
            call(CommandAction(id: SpotAction.open.arguments[0], title: entry.state.title, scope: .spot, after: .close), of: entry, text, onCard: true)
        case .list where entry.spot.pressRuns:
            call(CommandAction(id: SpotAction.open.arguments[0], title: entry.state.title, scope: .spot, after: .close), of: entry, text, onCard: true)
        case .list where entry.spot.soleCommand == nil:
            pushFirst(entry.id, moving: true)
            sheets[entry.id]?.type(text)
        default:
            run(seen: shown)
        }
    }

    public var marksSlash: Bool {
        slash != nil && openSheetID == nil && form == nil
    }

    public var slashPlaceholder: String? {
        guard let slash, slash.text.isEmpty, let shown = selectedEntry else { return nil }
        return commandOffer(of: shown)?.placeholder
    }

    var slashHint: String? {
        guard let slash, openSheetID == nil, form == nil, menu == nil, let entry = selectedEntry else { return nil }
        guard !slash.text.isEmpty || commandOffers[entry.id] != nil else { return nil }
        let title = commandOffers[entry.id]?.title ?? entry.state.title
        return slash.text.isEmpty ? "⏎ \(title)" : "⏎ \(title) \"\(slash.text)\""
    }

    private func call(_ action: CommandAction, of entry: Entry, _ text: String, onCard: Bool = false) {
        ask(action, on: (entry, nil)) { [sheets] in
            try await sheets[entry.id]?.launch(action, input: SearchQuery(text: text).input, onCard: onCard)
        }
    }

    private func commandOffer(of shown: Entry) -> CommandOffer? {
        commandOffers[shown.id] ?? shown.spot.soleCommand.flatMap { id in shown.spot.offers.first { $0.id == id && $0.confirm == nil } }
    }

    private static func commandItem(_ offer: CommandOffer) -> SpotItem {
        SpotItem(title: offer.title, run: offer.id, picture: Icon(text: offer.icon))
    }
}
