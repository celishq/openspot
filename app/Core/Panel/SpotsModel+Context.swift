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
        if cards.contains(where: { $0.spot.takes(value) }) { next.fill(id, with: value, look: entry(id).map { Self.look(of: $0.spot) }) } else { next.remove(id) }
        settle(next, motion: .fade)
    }

    func endContext(of id: String) {
        var next = context
        next.end(id)
        settle(next, motion: .fade)
    }

    func turnContext(by step: Int) {
        let isCycling = context.isSpread
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

    private static func look(of spot: Spot) -> ContextChip.Look {
        spot.fileIcon.map(ContextChip.Look.file) ?? .symbol(spot.symbol)
    }

    private func settle(_ next: ContextStack, motion: PanelMotion?) {
        guard next != context else { return }
        let before = (isOn: context.isOn, chip: context.selectedChip)
        change(isShown ? motion : nil, { context = next })
        placeContext(motion)
        guard before.isOn != next.isOn || before.chip != next.selectedChip else { return }
        holdMotion = motion
        selected = 0
        updateVisible()
        holdMotion = .edit
    }
}
