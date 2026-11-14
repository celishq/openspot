import Foundation

/// The grid: its selection, the presses of cards and keys, the chain of letters and the running work.
extension SpotsModel {
    /// A person pressed a key that they assigned to a command.
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

    /// The symbol the menu bar icon shows in place of itself: a pressed command's, else the toast's that shows, else none.
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

    /// How the card at this index shows: forward while its menu is open on the grid, faded while another card's is.
    public func focus(ofCard index: Int) -> CardFocus {
        guard menu != nil, openList == nil else { return .none }
        return index == selected ? .focused : .faded
    }

    /// Runs the card, unless the open menu owns the pointer, as after a force press whose click ends on the card. A click
    /// with ⌘ opens its Settings, as ⌘ Return does.
    public func tap(_ id: String, opening: Bool = false) {
        guard !menuOwnsPointer, let position = visible.firstIndex(where: { $0.id == id }) else { return }
        selected = position
        if !opening || !openSelectedSettings() { runSelected() }
    }

    public func setLevel(_ id: String, to value: Double) {
        sheets[id]?.setLevel(value)
    }

    /// Sends a change or a press of a component that a card draws (protocol: Layouts).
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

    /// Runs a command by its key, with the panel open only when its spot needs it.
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
        let moving = isShown
        host.show()
        open(id, moving: moving)
    }

    /// Notes which modifiers the person holds. The letters show once they have matched the entry key for a moment, so that
    /// a quick press shows nothing.
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

    /// Whether the spots show their letters: while the person holds the key that opens the panel, and in Edit Spots, where
    /// `L` gives them.
    public var showsChain: Bool {
        (isChainHeld && isOnGrid) || isEditing
    }

    /// The letter of a spot that has a key.
    public func chainLetter(of entry: Entry) -> String? {
        entry.letter?.name.uppercased()
    }

    private var isOnGrid: Bool {
        menu == nil && form == nil && openList == nil && !isEditing
    }

    /// Runs the spot whose letter this press holds, whatever the search shows, while the letters show. Before they show, a
    /// press with the same modifiers stays a key of the selected card, such as ⌘E. A spot with no sheet closes the panel.
    public func handleChain(code: UInt32, modifiers: Shortcut.Modifiers) -> Bool {
        guard isChainHeld, isOnGrid, let entry = entries.first(where: { entry in
            entry.letter.map { entryKey.chains(to: $0, code: code, modifiers: modifiers) } ?? false
        }) else { return false }
        press(entry.id)
        if entry.kind == .toggle { host.dismiss() }
        return true
    }

    public func run(_ entry: Entry) {
        if let item = entry.item, let list = entries.first(where: { $0.id == entry.spot.id }) {
            if item.records, openList != list.id {
                open(list.id, moving: true)
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
                open(entry.id, moving: true)
            }
        case .slider:
            break
        case .widget:
            if let opens = entry.spot.opens { press(opens) }
        }
    }

    /// Opens the Settings sheet of the selected card, as ⌘ Return does on the grid. It is false away from the grid and for a
    /// card with nothing to set, so the key goes on to the actions and the forms.
    public func openSelectedSettings() -> Bool {
        guard isOnGrid, let entry = selectedEntry else { return false }
        return openSettings(of: entry)
    }

    /// Opens the Settings sheet of a card, which the app makes and which grows from the card. Returns false for a card with
    /// nothing to set.
    @discardableResult
    public func openSettings(of entry: Entry) -> Bool {
        guard let id = settingsSheet(of: entry) else { return false }
        open(id, moving: true)
        return true
    }

    /// The ID of the Settings sheet of a card, or nil for a row, a sheet of the app, or a card with nothing to set.
    public func settingsSheet(of entry: Entry) -> String? {
        guard entry.item == nil, let settings = entry.spot.settingsSheet, settings.hasRows(in: loadedConfig ?? Config(text: "")) else { return nil }
        return SpotSettings.sheetID(of: entry.id)
    }

    /// The footer of the selected spot that has one command: Return sets its key until it has one, and runs it after, and
    /// ⌘ Return opens its settings.
    var soleHint: String? {
        guard openList == nil, let entry = selectedEntry, let command = entry.spot.soleCommand else { return nil }
        guard assignedKeys.contains(where: { $0.spot == entry.id && $0.act == .command(command) }) else {
            return "⏎ Set key   ⌘⏎ Settings   ⌘K Actions"
        }
        let title = entry.spot.offers.first?.title ?? command
        return "⏎ \(title)   ⌘⏎ Settings   ⌘K Actions"
    }

    /// Runs the one command of a spot as its key does. With no key yet, it opens the spot's key and records one, so the
    /// first Return sets up what each later Return runs.
    private func runSole(_ command: String, of entry: Entry) {
        if let key = assignedKeys.first(where: { $0.spot == entry.id && $0.act == .command(command) }) {
            if isShown { host.dismiss() }
            press(key)
        } else {
            openSettings(of: entry)
            toggleRecording(id: SpotSettings.keyRun(spot: entry.id, command: command))
        }
    }

    /// The marks of the scripts that show in the menu bar, by script.
    public var menuBarMarks: [(id: String, mark: MenuBarMark)] {
        runs.menuBarMarks
    }

    /// What the Openspot item shows for running work.
    public var workMark: MenuBarMark? {
        runs.workMark
    }

    /// Opens the panel with the spot of the oldest running work selected, or closes it when it already shows that. A search
    /// stays, so a spot that it hides is not selected. Returns false when no work shows.
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

    /// The running call of a part of the open sheet.
    public func work(of part: SpotPart) -> ScriptCall? {
        openSheet?.work(of: part)
    }

    /// The running call that a press of this row of the open menu stops.
    public func work(of row: ActionMenu.Row) -> ScriptCall? {
        menuTarget.flatMap { sheets[$0.entry.id]?.work(of: row, item: $0.item) }
    }

    /// Opens the list of a metric that is also a list, or else selects the widget that places it. Closes the panel
    /// when it already shows that. The icon of a spot that Return runs runs it, as Return does.
    public func openFromMenuBar(_ id: String) {
        if let entry = entries.first(where: { $0.id == id && $0.item == nil }), !entry.spot.showsValueInMenuBar, !entry.spot.opensOnReturn {
            let recordsFirst = entry.spot.soleCommand.map { command in !assignedKeys.contains { $0.spot == id && $0.act == .command(command) } } ?? false
            if recordsFirst { host.show() }
            return run(entry)
        }
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
}
