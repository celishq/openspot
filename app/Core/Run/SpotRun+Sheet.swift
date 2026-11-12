import Foundation

/// The sheet of a run: its open and close, its float and its places, and what wants its script.
extension SpotRun {
    /// Opens the sheet with its search kept. A sheet with a young answer opens at once with its parts. One with no answer
    /// runs `onReady` with its first answer: with `waits`, or after a short pause when that is late, and always for a script
    /// that holds its own state, which does not open when it cannot start.
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

    /// Stops what only an open sheet needs. A read that nothing else wants stops. A call that does work goes on.
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

    /// Moves the selection among its parts.
    public func movePart(by step: Int) {
        panel?.move(by: step)
    }

    public func scrollPanel(by step: Int) {
        nudge = SheetParts.Nudge(step: step, serial: nudge.serial + 1)
    }

    /// The script began to float: its sheet selects its first row and reads. A card reads only when its header lists
    /// `panel`, so that a float runs nothing that the panel would not.
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

    /// The sheet left a place, as when the panel or a float closed. Unless it still shows in a place in view, a sheet of
    /// parts, or of a script that holds its own state, closes. One with a field the person types in, or that holds its own
    /// state, drops its values, so that its next show reads again (K5, W7). A sheet of rows stays.
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

    /// The panel opened: an open sheet of rows is in view again and reads, by Events in the protocol and M2.
    func panelOpened() {
        if isOpen { read() }
        link.settle()
    }

    /// A scan looked at the folder: a stopped script that changed can start again (protocol: Modes).
    func scanned() {
        link.scanned()
    }

    /// Stops each read of this script, whose sheet no longer has a use for it, and ends the script.
    func stopReads() {
        if let read = running(Self.readKey) { stop(read) }
        if let answer = running(Self.answerKey) { stop(answer) }
        link.end()
    }

    /// Whether the person sees this sheet: it is the open one, and the panel shows.
    private var isInView: Bool {
        isOpen && runs.isPanelOpen || isFloating
    }

    /// Whether something wants this script now (protocol: Events), also a call of a staying script that waits for its `end`.
    var isWanted: Bool {
        isInView || runs.wants(spot) || link.holdsScript
    }

    /// Starts a script that stays and that something wants, and ends one that nothing wants.
    func settleScript() {
        link.settle()
    }

    /// Stops each call and lets go of the script, so that neither changes anything, and drops all that would start a new call.
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
        if let read = running(Self.readKey) { stop(read) }
        if let search = running(Self.searchKey) { stop(search) }
    }

    /// Closes a sheet that waits for an answer that will not come.
    func dropUnshownSheet() {
        guard runs.opening.dropMotion(of: spot.id) != nil else { return }
        runs.didClose(self)
        settle()
        runs.updateClock()
        onReport(.closed)
    }
}
