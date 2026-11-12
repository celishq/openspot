import Foundation

/// The open sheet: its open and close with their motions, the drop on the field, and its items with their picks.
extension SpotsModel {
    public var selectedEntry: Entry? {
        let list = visible
        guard list.indices.contains(selected) else { return nil }
        return list[selected]
    }

    /// Whether the search field keeps the keys: no form, no Edit Spots and no shown sheet of parts with no rows takes them.
    /// It follows the parts that show, so that the focus stays put while a sheet moves. A form of one choice keeps it, to
    /// search the rows of its options.
    public var showsSearch: Bool {
        if let form { return form.draft.choices != nil && !isEditing }
        return !isEditing && openSheet?.partsKind?.takesKeys != false
    }

    public var openPanel: SheetParts? {
        shownParts(of: openList)
    }

    /// The parts that the sheet of a spot shows: none while a form of that spot takes their place.
    public func shownParts(of id: String?) -> SheetParts? {
        guard let id, form?.entry.id != id else { return nil }
        return sheets[id]?.panel
    }

    public var openSheet: SpotRun? {
        openList.flatMap { sheets[$0] }
    }

    public var openEntry: Entry? {
        entries.first { $0.id == openList }
    }

    public var openItems: ItemList? {
        openSheet?.list
    }

    /// Clears the search, or else closes the open list. Returns false when there is nothing to step back from.
    public func stepBack() -> Bool {
        if !searchText.isEmpty {
            searchText = ""
        } else if openList != nil {
            closeList(moving: isShown)
        } else {
            return false
        }
        return true
    }

    /// Opens the sheet of a spot, as `openspot spot open` asks: in the panel that shows, or else in the panel that it shows.
    /// Returns false when no spot has that ID.
    public func openSheet(_ id: String) -> Bool {
        guard entries.contains(where: { $0.id == id }) else { return false }
        let moves = isShown
        if !moves { host.show() }
        endEditing(moving: false)
        open(id, moving: moves)
        return true
    }

    /// Opens the sheet of the spot that the config gives `⌘,`, the settings key of the Mac.
    public func openSettings() {
        guard let id = spot(openedBy: ActionKey(name: ",", isCommand: true)) else { return }
        open(id, moving: true)
    }

    /// Opens a sheet, which closes the run of the sheet before and stops a recording in it, and shows it once it is ready: at
    /// once, or with its first answer. It takes the place of a sheet that shows, grows out of its card when it moves, and
    /// shows in place when it does not move or has no card.
    public func open(_ id: String, moving: Bool) {
        if let shown = openList, shown != id { stopRecording() }
        sheets[id]?.open(waits: moving) { [weak self] in self?.showSheet(id, moving: moving) }
    }

    /// Closes the open sheet: back into its card when it moves, or at once.
    public func closeList(moving: Bool) {
        formAsk = nil
        stopRecording()
        showSheet(nil, moving: moving)
        runs.closeOpen()
    }

    /// Closes each sheet of parts when the panel has faded, stops the reads that nothing wants now, and drops the answers
    /// to the main search, which the next show asks again. A sheet of rows stays open.
    public func panelDidHide() {
        finishPick()
        for entry in entries where entry.spot.answers != nil { sheets[entry.id]?.answer("") }
        runs.panelClosed()
        if isFirstLaunch, !isWarming {
            isFirstLaunch = false
            host.confirm(entryKey.openHint)
        }
        endReview()
    }

    /// Starts the motion of the sheet to `list`. A sheet that opens while another shows takes its place, on the sheet's
    /// spring when it moves. Else a sheet grows out of its card and collapses back into it, and one that does not move or has
    /// no card shows and hides at once. A new sheet is built on its card first, and its grow starts on the next turn, so
    /// that the grow has a start.
    func showSheet(_ list: String?, moving: Bool) {
        guard list != openList else { return }
        if let list, openList != nil, transition.isOpen {
            change(moving ? .sheet(isOpen: true) : nil, { transition.show(list, moves: true) }) { [weak self] in
                self?.change(nil) { self?.transition.settle(list) }
            }
            return
        }
        guard moving, hasPlace(list ?? transition.id) else { return cutSheet(to: list) }
        guard let list else {
            animate(isOpen: false) {
                transition.hide(moves: true)
                holdFieldDrop()
            }
            return
        }
        change(nil) {
            transition.show(list, moves: true)
            holdFieldDrop()
        }
        DispatchQueue.main.async { [weak self] in
            self?.animate(isOpen: true) { self?.transition.start() }
        }
    }

    /// Shows or hides the sheet at once, with no motion.
    func cutSheet(to list: String?) {
        change(nil) {
            if let list { transition.show(list, moves: false) } else { transition.hide(moves: false) }
            fieldDrop = nil
            showsFieldDrop = false
        }
        if list == nil { endReview() }
    }

    /// Whether the built sheet has a place to close into: its card on the grid, or the field for the install screen.
    func hasPlace(_ id: String?) -> Bool {
        guard let id else { return false }
        return id == fieldSheet || SpotSheetCard.of(id, in: self) != nil
    }

    /// Moves the sheet on its spring, in one transaction, and ends the motion when it is done. The words of a review leave
    /// the field at once when its sheet is open, and fade when it has closed into the field.
    private func animate(isOpen: Bool, _ body: () -> Void) {
        var motion = 0
        change(.sheet(isOpen: isOpen), {
            body()
            motion = transition.motion
        }) { [weak self] in
            guard let self else { return }
            let isInstall = transition.id != nil && transition.id == fieldSheet
            change(nil) {
                self.transition.finish(motion)
                if isInstall, self.transition.phase == .open {
                    self.fieldDrop = nil
                    self.showsFieldDrop = false
                }
            }
            if isInstall, transition.phase == .closed { hideFieldDrop() }
            if transition.phase == .closed { endReview() }
        }
    }

    /// Keeps the words of a review in the field, where they lie under the sheet's header as the sheet grows out of the field or
    /// collapses back into it.
    private func holdFieldDrop() {
        guard let drop = reviewDrop else { return }
        fieldDrop = drop
        showsFieldDrop = true
    }

    /// Shows the words of a dragged `.spot` file in the field on the sheet's spring, and gives the field back its search when
    /// the drag leaves, unless a review holds them.
    func followSpotDrop(from old: SpotDrop?) {
        guard spotDrop != old else { return }
        if let drop = spotDrop {
            change(.sheet(isOpen: true)) {
                fieldDrop = drop
                showsFieldDrop = true
            }
        } else if !isReviewing {
            hideFieldDrop()
        }
    }

    /// Gives the field back its search on the sheet's closing spring, and lets the words go when they have faded.
    private func hideFieldDrop() {
        change(.sheet(isOpen: false), { showsFieldDrop = false }) { [weak self] in
            guard let self, !showsFieldDrop else { return }
            fieldDrop = nil
        }
    }

    /// Brings a sheet its first parts: on the sheet's spring when the sheet shows, so that it grows to its new size, and at
    /// once when it does not.
    func bringParts(of id: String, _ bring: () -> Void) {
        change(transition.id == id && transition.isOpen ? PanelMotion.sheet(isOpen: true) : nil, bring)
    }

    /// Makes a change on an animation, or with none at all, and calls `completion` when its motion has ended.
    public func change(_ motion: PanelMotion?, _ body: () -> Void, completion: @escaping @MainActor () -> Void = {}) {
        host.change(motion, body, completion: completion)
    }

    public func moveItem(by step: Int) {
        openSheet?.list.move(by: step)
    }

    public func moveItemLine(by lines: Int) {
        openSheet?.list.moveLine(by: lines)
    }

    public func runSelectedItem() {
        guard let item = openItems?.selectedItem else {
            createFromSearch()
            return
        }
        runItem(item)
    }

    /// The action that makes a new item from what the search did not find.
    public var createAction: CommandAction? {
        guard let list = openItems, !list.query.isEmpty, list.shown.isEmpty, list.search == .local else { return nil }
        return openEntry?.spot.actions.first { $0.scope == .spot && $0.isForm }
    }

    public func createFromSearch() {
        guard let action = createAction, let entry = openEntry else { return }
        openForm(action, on: (entry, nil), prefill: openItems?.query ?? "")
    }

    public func runItem(_ item: SpotItem) {
        guard let entry = openEntry else { return }
        pick(item, of: entry)
    }

    /// Records a pick and clears what it left open, once the panel has faded, so nothing moves during the fade.
    public func finishPick() {
        guard let pick = closingPick else { return }
        closingPick = nil
        remember(pick.item, of: pick.entry)
        closeList(moving: false)
    }

    /// Records a pick as recent, for a spot that keeps its recent picks.
    private func remember(_ item: SpotItem, of entry: Entry) {
        guard entry.spot.keepsRecent, let sheet = sheets[entry.id] else { return }
        sheet.list.remember(item)
        files.remember(sheet.list.recent, of: entry.id)
    }

    /// Runs a pick of a row, or an action on it. In the panel, a pick that closes it closes the panel. A float stays open
    /// with the picked row selected, and a pick that asks with a form or records a key opens the spot in the panel (W8).
    public func pick(_ item: SpotItem, of entry: Entry, action: CommandAction? = nil, in place: SheetPlace = .panel) {
        if place == .float {
            if action == nil, entry.spot.pickForm != nil || item.records { return press(entry.id) }
            remember(item, of: entry)
            sheets[entry.id]?.list.select(run: item.run)
        } else {
            if action == nil, item.records {
                toggleRecording(id: item.run)
                return
            }
            if action == nil, let form = entry.spot.pickForm {
                openForm(form, on: (entry, item))
                return
            }
            if action != nil || entry.spot.pick == .close {
                closingPick = (item, entry)
                if isShown {
                    host.dismiss()
                } else {
                    finishPick()
                }
            }
        }
        if let action {
            sheets[entry.id]?.run(action, item: item)
        } else {
            sheets[entry.id]?.pick(item)
        }
    }
}
