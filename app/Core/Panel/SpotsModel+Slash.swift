import Foundation

extension SpotsModel {
    func commandEntries(_ command: SlashCommand) -> [Entry] {
        let cards = Dictionary(cards.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        return commands.entries(matching: runs.search(of: command.word), text: command.text, limit: command.word.isEmpty ? .max : Self.searchLimit, cards: cards)
    }

    func launch(_ shown: Entry, with text: String) {
        guard let entry = entry(shown.spot.id) else { return }
        let offer = commands.button(of: shown)
        if text.isEmpty {
            if let offer { return run(CommandAction.command(offer), on: (entry, nil)) }
            return run(seen: entry)
        }
        if let offer {
            return call(CommandAction.command(offer), of: entry, text)
        }
        switch entry.spot.mainAct {
        case .run:
            call(CommandAction(id: SpotAction.open.arguments[0], title: entry.state.title, scope: .spot, after: .close), of: entry, text, onCard: true)
        case .sheet:
            pushFirst(entry.id, moving: true)
            sheets[entry.id]?.type(text)
        default:
            run(seen: entry)
        }
    }

    public var marksSlash: Bool {
        slash != nil && openSheetID == nil && form == nil
    }

    public var slashPlaceholder: String? {
        guard let slash, slash.text.isEmpty, let shown = selectedEntry else { return nil }
        return commands.button(of: shown).map { $0.placeholder } ?? shown.spot.placeholder
    }

    var slashHint: String? {
        guard let slash, openSheetID == nil, form == nil, menu == nil, let entry = selectedEntry else { return nil }
        let button = commands.button(of: entry)
        guard !slash.text.isEmpty || button != nil else { return nil }
        let title = button?.title ?? entry.state.title
        return slash.text.isEmpty ? "⏎ \(title)" : "⏎ \(title) \"\(slash.text)\""
    }

    private func call(_ action: CommandAction, of entry: Entry, _ text: String, onCard: Bool = false) {
        ask(action, on: (entry, nil)) { [sheets] in
            try await sheets[entry.id]?.launch(action, input: SearchQuery(text: text).input, onCard: onCard)
        }
    }
}
