import Foundation

extension SpotRun {
    public func open(need: ReadNeed = .moment, waits: Bool = false, onReady: @escaping () -> Void) {
        runs.willOpen(self)
        settle()
        list.selectFirst()
        if panel == nil, answered != nil { panel = lastAnswer.flatMap(SheetParts.init(output:)) }
        if answered == nil, link.keepsState || (waits && list.search == .local) {
            runs.opening.holdMotion(of: spot.id, limited: !link.keepsState, start: onReady)
        } else {
            onReady()
        }
        read(need: need)
        if !link.isReachable { dropUnshownSheet() }
        runs.updateClock()
    }

    public func close() {
        guard isOpen else { return }
        runs.didClose(self)
        settle()
        for (key, pause) in pauses where key != Self.levelKey {
            pause.cancel()
            pauses[key] = nil
        }
        if let search = running(Self.searchKey) { stop(search) }
        editing = nil
        runs.opening.dropMotion(of: spot.id)
        heardKind = nil
        if panel?.isSelectionMoved == true { panel?.clearSelection() }
        link.settle()
        stopUnwantedRead()
        runs.updateClock()
    }

    public func movePart(by step: Int) {
        panel?.move(by: step)
    }

    public func movePartLine(by lines: Int) -> Bool {
        panel?.moveLine(by: lines) ?? false
    }

    public func leaveRows() -> Bool {
        panel?.leaveRows() ?? false
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
        if panel == nil, answered != nil { panel = lastAnswer.flatMap(SheetParts.init(output:)) }
        if let read = spot.read, spot.kind.opensSheet || read.has(.panel) {
            self.read(reason: spot.kind.opensSheet ? .sheet : .panel)
        }
        link.settle()
        runs.updateClock()
    }

    func leftPlace() {
        if !isInView, panel != nil || link.keepsState {
            let wasOpen = isOpen
            close()
            if link.keepsState || panel?.parts.contains(where: \.isEditable) == true {
                panel = nil
                answered = nil
            }
            if wasOpen { onReport(.closed) }
        }
        stopUnwantedRead()
        link.settle()
    }

    func panelOpened() {
        if isOpen { read() }
        link.settle()
    }

    func scanned() {
        link.scanned()
    }

    func stopReads() {
        if let read = running(Self.readKey) { stop(read) }
        if let answer = running(Self.answerKey) { stop(answer) }
        link.end()
    }

    private var isInView: Bool {
        isOpen && runs.isPanelOpen || isFloating
    }

    var isWanted: Bool {
        isInView || runs.wants(spot) || link.holdsScript
    }

    func settleScript() {
        link.settle()
    }

    func prepareToQuit() {
        pauses.values.forEach { $0.cancel() }
        pauses = [:]
        waitingFiles = []
        waitingKeys = []
        readsAgain = false
        eventAgain = nil
        calls.forEach(stop)
        link.leave()
    }

    private func stopUnwantedRead() {
        guard !isWanted else { return }
        if let read = running(Self.readKey), !finishesRead { stop(read) }
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
