import Foundation

extension SpotsModel {
    public func press(_ key: GlobalKey) {
        asOnePress {
            if confirming == key, runConfirmed() { return }
            if confirmWords(of: key) != nil, showCard(key.spot) {
                confirming = key
                return
            }
            run(key)
        }
    }

    private func confirmWords(of key: GlobalKey) -> String? {
        guard case .command(let command) = key.act else { return nil }
        return sheets[key.spot]?.spot.commands.first { $0.id == command }?.confirm
    }

    var waitingWords: String? {
        guard openSheetID == nil, let key = confirming, let entry = selectedEntry, entry.id == key.spot || confirmKey(of: entry) == key else { return nil }
        return confirmWords(of: key)
    }

    func runConfirmed() -> Bool {
        guard waitingWords != nil, let key = confirming else { return false }
        if let entry = selectedEntry, entry.role == .action {
            give(to: entry)
            return true
        }
        confirming = nil
        hidePanel(after: .close)
        run(key)
        return true
    }

    private func run(_ key: GlobalKey) {
        if key.act == .open { return entry(key.spot).map(open(byKey:)) ?? () }
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

    private func open(byKey entry: Entry) {
        guard entry.soleCommand == nil else { return run(entry) }
        if entry.kind.opensSheet { endFlow() }
        press(entry.id)
    }

    public func menuBarSymbol(during toast: ToastKind?) -> String? {
        flashSymbol ?? toast?.symbol
    }

    public func moveSelection(dx: Int, dy: Int) {
        if let next = grid.neighbour(of: selected, in: placements, dx: dx, dy: dy) {
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

    public var dimsField: Bool {
        isMenuOpen && openSheetID != nil
    }

    public func marksMenu(ofCard index: Int) -> Bool {
        index == selected && openSheetID == nil
    }

    public func focus(ofCard index: Int) -> CardFocus {
        marksMenu(ofCard: index) && isMenuGrown ? .focused : .none
    }

    public func tap(_ id: String) {
        asOnePress {
            guard !menuOwnsPointer, let position = visible.firstIndex(where: { $0.id == id }) else { return }
            selected = position
            guard !isEditing else { return }
            guard openSheetID == nil else { return runSelectedItem() }
            runShown(visible[position])
        }
    }

    public func setLevel(_ id: String, to value: Double) {
        sheets[id]?.setLevel(value)
    }

    public func setCardPart(_ id: String, _ part: String, to value: String?) {
        sheets[id]?.setCardPart(part, to: value)
    }

    public func runSelected() {
        guard !isEditing else { return }
        if openSheetID != nil {
            runSelectedItem()
            return
        }
        guard let entry = selectedEntry else {
            if content == .attachment, isChipRefused { openSourceSettings() }
            return
        }
        runShown(entry)
    }

    private func runShown(_ entry: Entry) {
        if openWaiting(entry.spot.id) { return }
        switch content {
        case .attachment: give(to: entry)
        case .slash: launch(entry, with: slash?.text ?? "")
        case .cards, .search: run(seen: entry)
        }
    }

    func run(seen entry: Entry) {
        if entry.role == .answer, let sheet = sheets[entry.spot.id], sheet.isAnswering {
            sheet.afterAnswers { [weak self] in
                guard let self, let next = selectedEntry, next.role == .answer, next.spot.id == entry.spot.id else { return }
                run(next)
            }
            return
        }
        run(entry)
    }

    public func press(_ id: String) {
        asOnePress {
            guard let entry = entry(id), !openWaiting(entry.spot.id) else { return }
            if let sheet = sheets[id], sheet.awaitsAnswer {
                sheet.afterAnswer { [weak self] in self?.press(id) }
                return
            }
            guard entry.kind.opensSheet else {
                run(entry)
                return
            }
            presentSheet(of: id) { host.show() }
        }
    }




    private var isOnGrid: Bool {
        menu == nil && form == nil && openSheetID == nil && !isEditing
    }


    public func run(_ entry: Entry) {
        missedSearch.drop()
        if entry.spot.id == SettingsBook.searchSpot.id, let item = entry.item {
            openSettings(at: SettingsBook.place(of: item))
            return
        }
        if let item = entry.item, let list = self.entry(entry.spot.id) {
            if item.records, openSheetID != list.id {
                pushFirst(list.id, moving: true)
            }
            pick(item, of: list)
            return
        }
        if let sheet = sheets[entry.id], sheet.awaitsAnswer {
            sheet.afterAnswer { [weak self] in self?.run(entry) }
            return
        }
        markUsed(entry.id)
        switch entry.spot.mainAct {
        case .toggle:
            sheets[entry.id]?.pressCard()
        case .command where openSheetID == entry.id, .sheet where openSheetID == entry.id:
            closeSheet(moving: true)
        case .command(let command):
            runSole(command, of: entry)
        case .sheet:
            pushFirst(entry.id, moving: true)
        case .none:
            break
        }
    }

    public func openSelectedSettings() -> Bool {
        guard isOnGrid, let entry = selectedEntry else { return false }
        return openSettings(of: entry)
    }

    @discardableResult
    public func openSettings(of entry: Entry) -> Bool {
        hasSettings(entry) && openSettings(at: .spotOf(entry.id))
    }

    public func hasSettings(_ entry: Entry) -> Bool {
        entry.item == nil && entry.spot.rows != nil
    }

    var soleHint: String? {
        guard openSheetID == nil, let entry = selectedEntry, entry.item == nil, case .command(let command) = entry.spot.mainAct else { return nil }
        return "⏎ \(entry.spot.commands.first?.title ?? command)   ⌘⏎ Settings   ⌘K Actions"
    }

    private func runSole(_ command: String, of entry: Entry) {
        let key = assignedKeys.first { $0.spot == entry.id && $0.act == .command(command) }
            ?? GlobalKey(spot: entry.id, act: .command(command), trigger: .shake)
        if confirmWords(of: key) != nil {
            guard isShown else { return press(key) }
            if confirming != key || !runConfirmed() { confirming = key }
            return
        }
        hidePanel(after: entry.spot.commands.first { $0.id == command }.map(CommandAction.command)?.after ?? .close)
        run(key)
    }

    public var menuBarMarks: [(id: String, mark: MenuBarMark)] {
        runs.menuBarMarks
    }

    public var runningSummary: String? {
        runs.runningSummary
    }

    public var workCard: Work? {
        runs.workCard
    }

    public var unseenWork: [Work] {
        runs.unseenWork
    }

    public var workingIDs: Set<String> {
        runs.workingIDs
    }

    public func openAct() -> Bool {
        guard let id = runs.actSpot else { return false }
        let spot = { self.visible.firstIndex { $0.id == id } }
        if isShown, openSheetID == nil, spot() == selected {
            host.dismiss()
            return true
        }
        closeSheet(moving: isShown)
        host.show()
        if let spot = spot() { selected = spot }
        return true
    }

    public func act(of part: SpotPart) -> ScriptCall? {
        openSheet?.act(of: part)
    }

    public func act(of row: ActionMenu.Row) -> ScriptCall? {
        menuTarget.flatMap { sheets[$0.entry.id]?.act(of: row, item: $0.item) }
    }

    public func openFromMenuBar(_ id: String) {
        if isShown { host.dismiss() }
        float(id)
    }
}
