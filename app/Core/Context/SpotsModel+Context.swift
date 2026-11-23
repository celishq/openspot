import Foundation

extension SpotsModel {
    func openContext() {
        let front = isWarming ? nil : host.frontApp
        let feeds = !isWarming && entries.contains { entry in ContextValue.Kind.allCases.contains(where: entry.spot.takes) }
        let loading = feeds ? entries.filter { $0.spot.uses.contains(.context) && $0.spot.triggers.opensOverAnApp && $0.spot.triggers.opens(over: front) }.map(\.id) : []
        var next = context
        next.open(over: front, at: isWarming ? nil : host.frontAppPath, loading: loading)
        if next != context { context = next }
        runs.panelOpened(showsToEnd: isWarming, over: front, feedsContext: feeds)
    }

    func takeContext(_ value: ContextValue, of id: String) {
        var next = context
        if cards.contains(where: { $0.spot.takes(value) }) { next.fill(id, with: value) } else { next.remove(id) }
        settle(next, motion: .fade)
    }

    func endContext(of id: String) {
        var next = context
        next.end(id)
        settle(next, motion: .fade)
    }

    func turnContext(by step: Int) {
        var next = context
        next.turn(by: step)
        settle(next, motion: .edit)
    }

    func leaveContext() {
        var next = context
        next.leave()
        settle(next, motion: .edit)
    }

    public func pressContext() {
        _ = takeTab(back: false)
    }

    private func settle(_ next: ContextChips, motion: PanelMotion) {
        guard next != context else { return }
        let wasOn = context.isOn
        change(isShown ? motion : nil, { context = next })
        guard wasOn || next.isOn else { return }
        selected = 0
        updateVisible()
    }

    func showContext() -> [Entry] {
        guard let chip = context.selectedChip, let source = entry(chip.source) else { return [] }
        let words = chip.words
        let preview = Entry(spot: source.spot, item: SpotItem(title: words.title, run: Self.previewRun, picture: Icon(text: chip.symbol)), detail: words.detail)
        guard let value = chip.value else { return [preview] }
        let rows = cards.filter { $0.item == nil && $0.spot.takes(value) }.map { card in
            SpotItem(title: card.spot.name, subtitle: card.spot.subtitle, run: card.id, keywords: card.spot.keywords)
        }
        let text = query.trimmingCharacters(in: .whitespaces)
        let found: [SpotItem]
        if text.isEmpty {
            found = Array(rows.prefix(Self.contextRows))
        } else {
            var list = ItemList()
            list.replace(rows)
            found = runs.search(of: text).matching(in: [list], limit: Self.contextRows).map(\.item)
        }
        let taken = found.compactMap { row in
            entry(row.run).map { Entry(spot: $0.spot, item: SpotItem(title: row.title, run: Self.contextRun), detail: row.subtitle ?? Self.takes(value.kind)) }
        }
        return [preview] + taken
    }

    func isPreview(_ entry: Entry) -> Bool {
        entry.item?.run == Self.previewRun
    }

    func give(to entry: Entry) -> Bool {
        guard context.isOn, !isPreview(entry) else { return context.isOn }
        guard let value = context.selectedChip?.value else { return true }
        leaveContext()
        guard sheets[entry.spot.id]?.drop(value) == true else { return true }
        landDrop(on: entry.spot.id)
        return true
    }

    func takeTab(back: Bool) -> Bool? {
        guard openSheetID == nil, !isEditing else { return nil }
        if slash != nil { return completeSlash() }
        guard !context.chips.isEmpty else { return nil }
        turnContext(by: back ? -1 : 1)
        return true
    }

    private func completeSlash() -> Bool {
        guard let slash, let entry = selectedEntry, let word = commands.word(of: entry) else { return false }
        query = "\(slash.lead)/\(word) \(slash.tail.trimmingCharacters(in: .whitespaces))"
        return true
    }

    var contextHint: String? {
        guard openSheetID == nil, !isEditing, !context.chips.isEmpty else { return nil }
        guard context.isOn else { return "⇥ \(context.chips.count == 1 ? "Context" : "\(context.chips.count) Contexts")" }
        let run = selectedEntry.flatMap { isPreview($0) ? nil : "⏎ \($0.state.title)" }
        return [run, "⇥ Next", "Esc Leave"].compactMap { $0 }.joined(separator: "   ")
    }

    static let contextRows = 5
    static let contextRun = "openspot.context"
    static let previewRun = "openspot.context.preview"

    private static func takes(_ kind: ContextValue.Kind) -> String {
        switch kind {
        case .file: "Takes the files"
        case .url: "Takes the link"
        case .text: "Takes the text"
        }
    }
}
