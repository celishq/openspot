import Foundation

extension SpotRun {
    public func open(need: ShowNeed = .moment, waits: Bool = false, onReady: @escaping () -> Void) {
        runs.willOpen(self)
        acted()
        settle()
        list.selectFirst()
        if panel?.holdsParts != true, answered != nil { panel = lastAnswer.flatMap { SheetParts(output: $0, variants: runs.variants(of: spot.id)) } }
        let keepsState = script.keepsState
        if answered == nil, keepsState || (waits && list.search == .local) {
            runs.opening.holdMotion(of: spot.id, limited: !keepsState, start: onReady)
        } else {
            onReady()
        }
        show(need: need)
        if !isShowing, answered == nil { dropUnshownSheet() }
        if answered == nil, runs.isBuilding(spot) {
            after(Self.buildPause, key: Self.buildKey) { [weak self] in self?.sayBuilding() }
        }
        runs.updateClock()
    }

    private func sayBuilding() {
        guard isOpen, answered == nil, runs.isBuilding(spot) else { return }
        list.beginLoading(saying: "Openspot is building \(spot.name). This takes about half a minute, once.")
        runs.opening.startMotion(of: spot.id)
    }

    public func close() {
        guard isOpen else { return }
        sheetAgain = false
        runs.didClose(self)
        settle()
        for (key, pause) in pauses where key != Self.levelKey {
            pause.cancel()
            pauses[key] = nil
        }
        if let search = running(Self.searchKey) { stop(search) }
        editing = nil
        runs.opening.dropMotion(of: spot.id)
        heardRows = nil
        if panel?.isSelectionMoved == true { panel?.clearSelection() }
        link.settle()
        stopUnwantedShow()
        runs.updateClock()
    }

    func showPlace() {
        guard var next = panel else { return }
        next.show(in: runs.variants(of: spot.id))
        panel = next
    }

    public func movePart(by step: Int) {
        panel?.move(by: step)
    }

    public func movePartLine(by lines: Int) -> Bool {
        panel?.moveLine(by: lines) ?? false
    }

    public func focusPartEdge(last: Bool) -> Bool {
        panel?.focusEdge(last: last) ?? false
    }

    public func leaveRows(upward: Bool = false) -> Bool {
        panel?.leaveRows(upward: upward) ?? false
    }

    public func focusPart(_ id: String) {
        panel?.focus(id)
    }

    public func openMenu(of part: SpotPart) {
        menuOpening = SheetParts.MenuOpening(part: part.id, serial: (menuOpening?.serial ?? 0) + 1)
    }

    public func scrollPanel(by step: Int) {
        nudge = SheetParts.Nudge(step: step, serial: nudge.serial + 1)
    }

    func floated() {
        settle()
        list.selectFirst()
        if panel?.holdsParts != true, answered != nil { panel = lastAnswer.flatMap { SheetParts(output: $0, variants: runs.variants(of: spot.id)) } }
        show(event: spot.kind.opensSheet ? .sheet : .panel)
        link.settle()
        runs.updateClock()
    }

    func leftPlace() {
        if !isInView, script.keepsState {
            let wasOpen = isOpen
            close()
            panel = nil
            answered = nil
            if wasOpen { onReport(.closed) }
        } else if !isInView, !isOpen, panel?.parts.contains(where: \.isEditable) == true {
            panel = nil
            lastAnswer = keptSheet
            answered = keptSheet == nil ? nil : .distantPast
        }
        stopUnwantedShow()
        link.settle()
    }

    func panelOpened() {
        if isOpen, isShowCut {
            show(need: .change)
        } else if isOpen, panel?.holdsParts != true {
            show()
        }
        isShowCut = false
        link.settle()
    }

    func scanned(_ stamp: [Int]?) {
        link.scanned(stamp)
    }

    func stopShows() {
        if let show = running(Self.showKey) { stop(show) }
        if let answer = running(Self.answerKey) { stop(answer) }
        link.end()
    }

    private var isInView: Bool {
        isOpen && runs.isPanelOpen || isFloating
    }

    var isWanted: Bool {
        isInView || runs.wants(spot) || (!calls.isEmpty && script.keepsState)
    }

    func settleScript() {
        link.settle()
    }

    func prepareToQuit() {
        pauses.values.forEach { $0.cancel() }
        pauses = [:]
        waitingFiles = []
        waitingKeys = []
        showsAgain = false
        sheetAgain = false
        eventAgain = nil
        calls.forEach(stop)
        link.leave()
    }

    private func stopUnwantedShow() {
        guard !isWanted else { return }
        if let show = running(Self.showKey), !finishesShow {
            stop(show)
            isShowCut = isOpen
        }
        if let search = running(Self.searchKey) { stop(search) }
    }

    func dropUnshownSheet() {
        guard runs.opening.dropMotion(of: spot.id) != nil else { return }
        runs.didClose(self)
        settle()
        runs.updateClock()
        onReport(.closed)
    }
}
