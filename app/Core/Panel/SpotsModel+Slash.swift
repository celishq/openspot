import Foundation

extension SpotsModel {
    func commandEntries(_ command: SlashCommand) -> [Entry] {
        commands.entries(matching: runs.search(of: command.word), text: command.text, limit: command.word.isEmpty ? .max : Self.searchLimit)
    }

    func launch(_ shown: Entry, with text: String) {
        guard let entry = entry(shown.spot.id) else { return }
        let button = commands.button(of: shown)
        if text.isEmpty {
            if let button { return run(button, on: (entry, nil)) }
            return run(seen: entry)
        }
        if let button {
            return call(button, of: entry, text)
        }
        switch entry.spot.mainAct {
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
            try await sheets[entry.id]?.launch(action, search: SearchQuery(text: text), onCard: onCard)
        }
    }
}
