import Foundation

extension SpotsModel {
    public func press(_ key: GlobalKey) {
        guard case .command(let command) = key.act else { return float(key.spot) }
        guard let sheet = sheets[key.spot] else { return }
        sheet.pressKey(command)
        flashSymbol = sheet.spot.symbol(of: command)
        flashWatch?.cancel()
        flashWatch = Task { [weak self, flashPause] in
            try? await Task.sleep(for: flashPause)
            if !Task.isCancelled { self?.flashSymbol = nil }
        }
    }

    public func menuBarSymbol(during toast: ToastKind?) -> String? {
        flashSymbol ?? toast?.symbol
    }

    public func moveSelection(dx: Int, dy: Int) {
        if let next = SpotGrid().neighbour(of: selected, in: placements, dx: dx, dy: dy) {
            selected = next
        }
    }

    public var selectedIsSlider: Bool {
        selectedEntry?.kind == .slider
    }

    public func adjustSelected(by delta: Double) {
        guard let entry = selectedEntry, entry.kind == .slider else { return }
        sheets[entry.id]?.setLevel((entry.state.level ?? 0) + delta)
    }

    public func focus(ofCard index: Int) -> CardFocus {
        guard isMenuOpen, openList == nil else { return .none }
        return index == selected ? .focused : .faded
    }

    public func tap(_ id: String, opening: Bool = false) {
        guard !menuOwnsPointer, let position = visible.firstIndex(where: { $0.id == id }) else { return }
        selected = position
        if !opening || !openSelected() { runSelected() }
    }

    public func setLevel(_ id: String, to value: Double) {
        sheets[id]?.setLevel(value)
    }

    public func setCardPart(_ id: String, _ part: String, to value: String?) {
        sheets[id]?.setCardPart(part, to: value)
    }

    public func runSelected() {
        guard !isEditing else { return }
        if openList != nil {
            runSelectedItem()
            return
        }
        guard let entry = selectedEntry else { return }
        if entry.isAnswer, let sheet = sheets[entry.spot.id], sheet.isAnswering {
            sheet.afterAnswers { [weak self] in
                guard let self, let next = selectedEntry, next.isAnswer, next.spot.id == entry.spot.id else { return }
                run(next)
            }
            return
        }
        run(entry)
    }

    @discardableResult
    public func openSelected() -> Bool {
        guard isOnGrid, let entry = selectedEntry, entry.item == nil, entry.spot.pressRuns, entry.kind.opensSheet else { return false }
        presentSheet(of: entry.id, moving: true)
        return true
    }

    public func press(_ id: String) {
        guard let entry = entries.first(where: { $0.id == id }) else { return }
        if let sheet = sheets[id], sheet.awaitsAnswer {
            sheet.afterAnswer { [weak self] in self?.press(id) }
            return
        }
        guard entry.kind.opensSheet, !entry.spot.pressRuns else {
            run(entry)
            return
        }
        presentSheet(of: id, moving: isShown) { host.show() }
    }

    public func takeHeld(_ modifiers: Shortcut.Modifiers) {
        chainWatch?.cancel()
        guard modifiers == entryKey.modifiers else {
            isChainHeld = false
            return
        }
        chainWatch = Task { [weak self] in
            try? await Task.sleep(for: Self.chainPause)
            if !Task.isCancelled { self?.isChainHeld = true }
        }
    }

    public var showsChain: Bool {
        (isChainHeld && isOnGrid) || isEditing
    }

    public func chainLetter(of entry: Entry) -> String? {
        entry.letter?.name.uppercased()
    }

    private var isOnGrid: Bool {
        menu == nil && form == nil && openList == nil && !isEditing
    }

    public func handleChain(code: UInt32, modifiers: Shortcut.Modifiers) -> Bool {
        guard isOnGrid, let entry = entries.first(where: { entry in
            entry.letter.map { entryKey.chains(to: $0, code: code, modifiers: modifiers) } ?? false
        }) else { return false }
        press(entry.id)
        if entry.kind == .toggle { host.dismiss() }
        return true
    }

    public func run(_ entry: Entry) {
        if let item = entry.item, let list = entries.first(where: { $0.id == entry.spot.id }) {
            if item.records, openList != list.id {
                pushFirst(list.id, moving: true)
            }
            pick(item, of: list)
            return
        }
        if let sheet = sheets[entry.id], sheet.awaitsAnswer {
            sheet.afterAnswer { [weak self] in self?.run(entry) }
            return
        }
        switch entry.kind {
        case .toggle:
            sheets[entry.id]?.pressCard()
        case .launch:
            if isShown, sheets[entry.id]?.isCardRunning != true, !entry.spot.takesDrops { host.dismiss() }
            sheets[entry.id]?.pressCard()
        case .list where entry.spot.pressRuns:
            if isShown, sheets[entry.id]?.isCardRunning != true { host.dismiss() }
            sheets[entry.id]?.pressCard()
        case .list:
            if openList == entry.id {
                closeList(moving: true)
            } else if let command = entry.spot.soleCommand {
                runSole(command, of: entry)
            } else {
                pushFirst(entry.id, moving: true)
            }
        case .slider:
            break
        case .widget:
            if let opens = entry.spot.opens { press(opens) }
        }
    }

    public func openSoleSettings() -> Bool {
        guard openList == nil, let entry = selectedEntry, entry.spot.soleCommand != nil else { return false }
        pushFirst(entry.id, moving: true)
        return true
    }

    var soleHint: String? {
        guard openList == nil, let entry = selectedEntry, let command = entry.spot.soleCommand else { return nil }
        guard assignedKeys.contains(where: { $0.spot == entry.id && $0.act == .command(command) }) else {
            return "⏎ Set key   ⌘⏎ Settings   ⌘K Actions"
        }
        let title = entry.spot.offers.first?.title ?? command
        return "⏎ \(title)   ⌘⏎ Settings   ⌘K Actions"
    }

    private func runSole(_ command: String, of entry: Entry) {
        if let key = assignedKeys.first(where: { $0.spot == entry.id && $0.act == .command(command) }) {
            if isShown { host.dismiss() }
            press(key)
        } else {
            pushFirst(entry.id, moving: true)
            toggleRecording(id: KeyList.keyRun(spot: entry.id, command: command))
        }
    }

    public var menuBarMarks: [(id: String, mark: MenuBarMark)] {
        runs.menuBarMarks
    }

    public var runningSummary: String? {
        runs.runningSummary
    }

    public func openWork() -> Bool {
        guard let id = runs.workSpot else { return false }
        let spot = { self.visible.firstIndex { $0.id == id || $0.spot.places.contains(id) } }
        if isShown, openList == nil, spot() == selected {
            host.dismiss()
            return true
        }
        closeList(moving: isShown)
        host.show()
        if let spot = spot() { selected = spot }
        return true
    }

    public func work(of part: SpotPart) -> ScriptCall? {
        openSheet?.work(of: part)
    }

    public func work(of row: ActionMenu.Row) -> ScriptCall? {
        menuTarget.flatMap { sheets[$0.entry.id]?.work(of: row, item: $0.item) }
    }

    public func openFromMenuBar(_ id: String) {
        let opens = entries.first { $0.id == id && $0.kind.opensSheet }?.id
        if isShown, opens == nil || openList == opens {
            host.dismiss()
        } else if let opens {
            press(opens)
        } else {
            closeList(moving: isShown)
            host.show()
            selected = visible.firstIndex { $0.spot.places.contains(id) } ?? 0
        }
    }

    public func openBigView() {
        guard let entry = selectedEntry else { return }
        host.notify("\(entry.state.title) has no big view yet.")
    }
}
