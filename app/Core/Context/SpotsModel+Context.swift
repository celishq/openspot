import Foundation

extension SpotsModel {
    func openContext() {
        guard !isContextOpen else { return runs.panelOpened() }
        isContextOpen = !isWarming
        let wasOn = context.isOn
        let front = isWarming ? nil : host.frontApp
        let feeds = !isWarming && entries.contains { entry in ContextValue.Kind.allCases.contains(where: entry.spot.triggers.drop.takes) }
        let loading = feeds ? entries.filter { $0.spot.isSource && $0.spot.triggers.opensOverAnApp && $0.spot.runsOnOpen(over: front?.bundleID, feedsContext: feeds) } : []
        var next = context
        next.open(over: front, loading: loading.map { ($0.id, Self.look(of: $0.spot)) })
        if next != context { context = next }
        resetContextSpread()
        if wasOn { updateVisible() }
        runs.panelOpened(showsToEnd: isWarming, over: front?.bundleID, feedsContext: feeds)
    }

    func takeContext(_ value: ContextValue, of id: String) {
        var next = context
        if cards.contains(where: { $0.spot.takes(value) }) { next.fill(id, with: value, look: entry(id).map { Self.look(of: $0.spot) }) } else { next.remove(id) }
        settle(next, motion: .fade)
    }

    func endContext(of id: String) {
        var next = context
        next.end(id)
        settle(next, motion: .fade)
    }

    func turnContext(by step: Int) {
        spreadContext()
        var next = context
        next.turn(by: step)
        settle(next, motion: .edit)
    }

    func leaveContext() {
        endSpread()
        var next = context
        next.leave()
        settle(next, motion: .edit)
    }

    public func pressContext() {
        guard openSheetID == nil, !isEditing, !context.chips.isEmpty else { return }
        turnContext(by: 1)
    }

    private static func look(of spot: Spot) -> ContextChip.Look {
        spot.fileIcon.map(ContextChip.Look.file) ?? .symbol(spot.symbol)
    }

    private func settle(_ next: ContextChips, motion: PanelMotion) {
        guard next != context else { return }
        let before = (isOn: context.isOn, chip: context.selectedChip)
        change(isShown ? motion : nil, { context = next })
        placeContext(motion)
        guard before.isOn != next.isOn || before.chip != next.selectedChip else { return }
        selected = 0
        updateVisible()
    }

    func showContext() -> [Entry] {
        guard let chip = context.selectedChip, let source = entry(chip.source) else { return [] }
        guard let value = chip.value else {
            return [Entry(spot: source.spot, item: SpotItem(title: chip.words.title, run: "", picture: Icon(text: chip.symbol)), role: .preview, detail: "")]
        }
        let shown = ContextPreview(value)
        let preview = Entry(spot: source.spot, item: SpotItem(title: shown.text, run: "", picture: shown.picture), role: .preview, detail: shown.caption)
        let text = query.trimmingCharacters(in: .whitespaces)
        let found = commands.takers(of: value, matching: text.isEmpty ? nil : runs.search(of: text), limit: Self.contextRows)
        let taken = found.compactMap { row in
            entry(row.spot).map { Entry(spot: $0.spot, item: SpotItem(title: row.title, run: ""), role: .taker, detail: Self.takes(value.kind)) }
        }
        return [preview] + taken
    }

    func give(to entry: Entry) {
        guard entry.role != .preview, let value = context.selectedChip?.value else { return }
        landDrop(value, on: entry.spot.id, leavesContext: true)
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
        let run = selectedEntry.flatMap { $0.role == .preview ? nil : "⏎ \($0.state.title)" }
        return [run, "⇥ Next", "Esc Leave"].compactMap { $0 }.joined(separator: "   ")
    }

    static let contextRows = 5

    private static func takes(_ kind: ContextValue.Kind) -> String {
        switch kind {
        case .file: "Takes the files"
        case .url: "Takes the link"
        case .text: "Takes the text"
        }
    }
}
