import Foundation

extension SpotsModel {
    func openContext() {
        guard !isContextOpen else { return runs.panelOpened() }
        isContextOpen = !isWarming
        let wasOn = context.isOn
        let front = isWarming ? nil : host.frontApp
        let feeds = !isWarming && entries.contains { entry in ContextValue.Kind.allCases.contains(where: entry.spot.triggers.drop.takes) }
        let loading = feeds ? entries.filter { $0.spot.isSource && $0.spot.triggers.opensOverAnApp && $0.spot.runsOnOpen(over: front?.bundleID, feedsContext: feeds) } : []
        endSpread()
        isContextMoving = false
        var next = context
        next.open(over: front, loading: loading.map { ($0.id, Self.look(of: $0.spot)) })
        if next != context { context = next }
        if wasOn { updateVisible() }
        runs.panelOpened(showsToEnd: isWarming, over: front?.bundleID, feedsContext: feeds)
    }

    func takeContext(_ value: ContextValue, of id: String) {
        var next = context
        if cards.contains(where: { $0.spot.takes(value) }) { next.fill(id, with: value, look: entry(id).flatMap { Self.look(of: $0.spot) }) } else { next.remove(id) }
        settle(next, motion: .fade)
    }

    func endContext(of id: String) {
        var next = context
        next.end(id)
        settle(next, motion: .fade)
    }

    func turnContext(by step: Int) {
        let isCycling = context.layout.isSpread
        spreadContext()
        var next = context
        next.turn(by: step)
        settle(next, motion: isCycling ? nil : .edit)
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

    private static func look(of spot: Spot) -> ContextChip.Look? {
        spot.fileIcon.map(ContextChip.Look.file) ?? (spot.symbol.isEmpty ? nil : .symbol(spot.symbol))
    }

    private func settle(_ next: ContextStack, motion: PanelMotion?) {
        guard next != context else { return }
        let before = (isOn: context.isOn, chip: context.selectedChip)
        change(isShown ? motion : nil, { context = next })
        placeContext(motion)
        guard before.isOn != next.isOn || before.chip != next.selectedChip else { return }
        selected = 0
        updateVisible(holding: motion)
    }

    func give(to entry: Entry) {
        guard let value = context.selectedChip?.value else { return }
        landDrop(value, on: entry.spot.id, leavesContext: true)
    }

    func takeTab(back: Bool) -> Bool? {
        guard openSheetID == nil, !isEditing else { return nil }
        if slash != nil { return completeSlash() }
        guard !context.chips.isEmpty else { return nil }
        turnContext(by: back ? -1 : 1)
        return true
    }

    var contextHint: String? {
        guard openSheetID == nil, !isEditing, !context.chips.isEmpty else { return nil }
        guard context.isOn else { return "⇥ \(context.chips.count == 1 ? "Context" : "\(context.chips.count) Contexts")" }
        let run = selectedEntry.map { "⏎ \($0.state.title)" }
        return [run, "⇥ Next", "Esc Leave"].compactMap { $0 }.joined(separator: "   ")
    }

    func showContext(holding motion: PanelMotion?) -> [Entry] {
        guard let chip = context.selectedChip, entry(chip.source) != nil else {
            hold(nil, motion: motion)
            return []
        }
        guard let value = chip.value else {
            hold(.loading, motion: motion)
            return []
        }
        hold(ContextPreview(value), motion: motion)
        let text = query.trimmingCharacters(in: .whitespaces)
        let found = commands.takers(of: value, matching: text.isEmpty ? nil : runs.search(of: text), limit: Self.takerLimit)
        let taken = found.compactMap { row in
            entry(row.spot).map { Entry(spot: $0.spot, item: SpotItem(title: row.title, run: ""), role: .taker, detail: value.kind.takerWords) }
        }
        return taken
    }

    func hold(_ preview: ContextPreview?, motion: PanelMotion?) {
        guard preview != fieldValue.preview else { return }
        change(isShown ? motion : nil) { fieldValue = FieldValue(preview) }
    }

    static let takerLimit = 5

    func spreadContext() {
        contextWatch?.cancel()
        let pause = contextPause
        contextWatch = Task { [weak self] in
            try? await Task.sleep(for: pause, tolerance: pause / 10)
            guard !Task.isCancelled else { return }
            self?.foldContext()
        }
    }

    func endSpread() {
        contextWatch?.cancel()
        contextWatch = nil
    }

    func placeContext(_ motion: PanelMotion?) {
        guard !isContextMoving else { return }
        var next = context
        next.place(spreads: contextWatch != nil)
        guard next != context else { return }
        guard let motion, isShown else {
            context = next
            return
        }
        isContextMoving = true
        change(motion, { context = next }) { [weak self] in
            self?.isContextMoving = false
            self?.placeContext(.edit)
        }
    }

    private func foldContext() {
        endSpread()
        placeContext(.edit)
    }
}
